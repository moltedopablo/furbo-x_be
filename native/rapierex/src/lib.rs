// extern crate rapier2d;
use rapier2d::prelude::*;
use rustler::NifMap;

#[derive(NifMap)]
pub struct Ball {
    pub position: (f32, f32),
    pub lin_vel: (f32, f32),
    pub shoot_dir: (f32, f32),
}
#[derive(NifMap)]
pub struct Player {
    pub id: i32,
    pub position: (f32, f32),
    pub lin_vel: (f32, f32),
    pub movement: (f32, f32),
}

#[rustler::nif]
fn step(ball: Ball, players: Vec<Player>) -> (Ball, Vec<Player>) {
    let mut rigid_body_set = RigidBodySet::new();
    let mut collider_set = ColliderSet::new();

    /* Create the ground. */
    // let collider = ColliderBuilder::cuboid(100.0, 0.1).build();
    // collider_set.insert(collider);

    /* Create the bouncing ball. */
    let mut rigid_body = RigidBodyBuilder::dynamic()
        .position(Isometry::new(
            vector![ball.position.0, ball.position.1],
            0.0,
        ))
        .linvel(vector![ball.lin_vel.0, ball.lin_vel.1])
        .linear_damping(0.5)
        .build();
    if ball.shoot_dir.0 != 0.0 || ball.shoot_dir.1 != 0.0 {
        rigid_body.add_force(vector![ball.shoot_dir.0, ball.shoot_dir.1], true);
    }
    let collider = ColliderBuilder::ball(1.0).restitution(0.7).build();
    let ball_body_handle = rigid_body_set.insert(rigid_body);
    collider_set.insert_with_parent(collider, ball_body_handle, &mut rigid_body_set);

    /* Create characters */
    let mut character_body_handles = Vec::new();
    let mut cloned_players: Vec<Player> = Vec::new();
    for player in players {
        let mut rigid_body = RigidBodyBuilder::dynamic()
            .position(Isometry::new(
                vector![player.position.0, player.position.1],
                0.0,
            ))
            .linvel(vector![player.lin_vel.0, player.lin_vel.1])
            .linear_damping(1.4)
            .build();

        if player.movement.0 != 0.0 || player.movement.1 != 0.0 {
            rigid_body.set_linvel(
                vector![player.movement.0 * 20.0, player.movement.1 * 20.0],
                true,
            );
        }
        let collider = ColliderBuilder::ball(1.0).restitution(0.7).build();
        let character_body_handle = rigid_body_set.insert(rigid_body);
        collider_set.insert_with_parent(collider, character_body_handle, &mut rigid_body_set);
        character_body_handles.push(character_body_handle);
        cloned_players.push(player);
    }

    // move character to the right
    // let character_body = rigid_body_set[character_body_handle];

    /* Create other structures necessary for the simulation. */
    let gravity = vector![0.0, 0.0];
    let integration_parameters = IntegrationParameters::default();
    let mut physics_pipeline = PhysicsPipeline::new();
    let mut island_manager = IslandManager::new();
    let mut broad_phase = DefaultBroadPhase::new();
    let mut narrow_phase = NarrowPhase::new();
    let mut impulse_joint_set = ImpulseJointSet::new();
    let mut multibody_joint_set = MultibodyJointSet::new();
    let mut ccd_solver = CCDSolver::new();
    let mut query_pipeline = QueryPipeline::new();
    let physics_hooks = ();
    let event_handler = ();

    physics_pipeline.step(
        &gravity,
        &integration_parameters,
        &mut island_manager,
        &mut broad_phase,
        &mut narrow_phase,
        &mut rigid_body_set,
        &mut collider_set,
        &mut impulse_joint_set,
        &mut multibody_joint_set,
        &mut ccd_solver,
        Some(&mut query_pipeline),
        &physics_hooks,
        &event_handler,
    );

    let ball_body = &rigid_body_set[ball_body_handle];
    let mut updated_players = Vec::new();
    for (i, handle) in character_body_handles.iter().enumerate() {
        let character_body = &rigid_body_set[*handle];
        updated_players.push(Player {
            id: cloned_players[i].id.clone(), // Borrow the name and clone the string
            position: (
                character_body.translation().x,
                character_body.translation().y,
            ),
            lin_vel: (character_body.linvel().x, character_body.linvel().y),
            movement: (0.0, 0.0),
        });
    }
    return (
        Ball {
            position: (ball_body.translation().x, ball_body.translation().y),
            lin_vel: (ball_body.linvel().x, ball_body.linvel().y),
            shoot_dir: (0.0, 0.0),
        },
        updated_players,
    );
}

rustler::init!("Elixir.RapierEx");
