// extern crate rapier2d;
use rapier2d::prelude::*;
use rustler::NifMap;

#[derive(NifMap)]
pub struct Ball {
    pub position: (f32, f32),
    pub lin_vel: (f32, f32),
    pub shoot_dir: (f32, f32),
    pub scale: f32,
}
#[derive(NifMap)]
pub struct Player {
    pub id: i32,
    pub position: (f32, f32),
    pub lin_vel: (f32, f32),
    pub movement: (f32, f32),
    pub scale: f32,
}
#[derive(NifMap)]
pub struct Court {
    pub width: f32,
    pub height: f32,
    pub goal_width: f32,
    pub goal_depth: f32,
}

#[rustler::nif]
fn step(ball: Ball, court: Court, players: Vec<Player>) -> (Ball, Vec<Player>) {
    let mut rigid_body_set = RigidBodySet::new();
    let mut collider_set = ColliderSet::new();

    let walls_restituion = 1.0;
    /* Create the court. Upper and Lower sides */
    let collider = ColliderBuilder::polyline(
        vec![
            point![-court.width / 2.0, court.goal_width / 2.0],
            point![-court.width / 2.0, court.height / 2.0],
            point![court.width / 2.0, court.height / 2.0],
            point![court.width / 2.0, court.goal_width / 2.0],
        ],
        None,
    )
    .restitution(walls_restituion);
    collider_set.insert(collider);

    let collider = ColliderBuilder::polyline(
        vec![
            point![-court.width / 2.0, -court.goal_width / 2.0],
            point![-court.width / 2.0, -court.height / 2.0],
            point![court.width / 2.0, -court.height / 2.0],
            point![court.width / 2.0, -court.goal_width / 2.0],
        ],
        None,
    )
    .restitution(walls_restituion);
    collider_set.insert(collider);

    /* Create left goal */
    let collider = ColliderBuilder::polyline(
        vec![
            point![-court.width / 2.0, court.goal_width / 2.0],
            point![
                -court.width / 2.0 - court.goal_depth,
                court.goal_width / 2.0
            ],
            point![
                -court.width / 2.0 - court.goal_depth,
                -court.goal_width / 2.0
            ],
            point![-court.width / 2.0, -court.goal_width / 2.0],
        ],
        None,
    )
    .restitution(walls_restituion);
    collider_set.insert(collider);

    /* Create right goal */
    let collider = ColliderBuilder::polyline(
        vec![
            point![court.width / 2.0, court.goal_width / 2.0],
            point![court.width / 2.0 + court.goal_depth, court.goal_width / 2.0],
            point![
                court.width / 2.0 + court.goal_depth,
                -court.goal_width / 2.0
            ],
            point![court.width / 2.0, -court.goal_width / 2.0],
        ],
        None,
    )
    .restitution(walls_restituion);
    collider_set.insert(collider);

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
        rigid_body.set_linvel(
            vector![ball.shoot_dir.0 * 18.0, ball.shoot_dir.1 * 18.0],
            true,
        );
    }
    let collider = ColliderBuilder::ball(ball.scale).restitution(0.9).build();
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
            .linear_damping(5.0)
            .build();

        if player.movement.0 != 0.0 {
            rigid_body.set_linvel(
                vector![player.movement.0 * 10.0, rigid_body.linvel().y],
                true,
            );
        }
        if player.movement.1 != 0.0 {
            rigid_body.set_linvel(
                vector![rigid_body.linvel().x, player.movement.1 * 10.0],
                true,
            );
        }
        let collider = ColliderBuilder::ball(player.scale).restitution(0.9).build();
        let character_body_handle = rigid_body_set.insert(rigid_body);
        collider_set.insert_with_parent(collider, character_body_handle, &mut rigid_body_set);
        character_body_handles.push(character_body_handle);
        //Clone players to be able to return them later
        cloned_players.push(player);
    }

    /* Create other structures necessary for the simulation. */
    // Gravity is zero because we are in 2D top down game
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
            scale: cloned_players[i].scale.clone(),
        });
    }
    return (
        Ball {
            position: (ball_body.translation().x, ball_body.translation().y),
            lin_vel: (ball_body.linvel().x, ball_body.linvel().y),
            shoot_dir: (0.0, 0.0),
            scale: ball.scale.clone(),
        },
        updated_players,
    );
}

rustler::init!("Elixir.RapierEx");
