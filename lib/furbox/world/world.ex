defmodule Furbox.World do
  use GenServer

  @initial_world_state %{
    :ball => %{
      :position => {0.0, 0.0},
      :lin_vel => {0.0, 0.0},
      :shoot_dir => {5000.0, 0.0}
    },
    :players => []
  }

  # Client
  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(_default) do
    IO.inspect("Starting world")
    GenServer.start_link(__MODULE__, @initial_world_state, name: FurboxWorld)
  end

  defp step(state) do
    IO.inspect("Running step")
    # {player_x, player_y} = state[:players] |> List.first() |> Map.get(:position)
    # {player_vel_x, player_vel_y} = state[:players] |> List.first() |> Map.get(:lin_vel)
    # {player_movement_x, player_movement_y} = state[:players] |> List.first() |> Map.get(:movement)

    # IO.inspect("Calling RapierEx.step(#{ball_x}, #{y_float})")
    {new_ball, new_players} =
      RapierEx.step(
        state.ball,
        state.players
      )

    new_state =
      Map.put(state, :ball, Map.merge(state.ball, new_ball))
      |> Map.put(
        :players,
        Enum.map(state.players, fn p ->
          Map.merge(p, new_players |> Enum.find(fn np -> np[:id] == p[:id] end))
        end)
      )

    IO.inspect(new_state)
    FurboxWeb.Endpoint.broadcast("furbox:main", "game_changed", new_state |> clean_state)
    {:ok, new_state}
  end

  @spec run_step() :: any()
  def run_step() do
    GenServer.call(FurboxWorld, :run_step)
  end

  def get_state() do
    GenServer.call(FurboxWorld, :get_state)
  end

  def move_player(player, position_offset) do
    GenServer.call(FurboxWorld, {:move_player, player, position_offset})
  end

  def new_player() do
    GenServer.call(FurboxWorld, {:new_player})
  end

  # Server (callbacks)
  @impl true
  def init(arg) do
    {:ok, arg}
  end

  defp clean_state(state) do
    # JSON Encoder doesn't like tuples
    %{
      ball: %{position: [state.ball.position |> elem(0), state.ball.position |> elem(1)]},
      players:
        Enum.map(state.players, fn p ->
          %{id: p.id, position: [p.position |> elem(0), p.position |> elem(1)]}
        end)
    }
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state |> clean_state, state}
  end

  @impl true
  def handle_call(:run_step, _from, state) do
    {:ok, new_state} = step(state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:move_player, player_id, [offset_x, offset_y]}, _from, state) do
    new_state =
      Map.update!(state, :players, fn players ->
        Enum.map(players, fn p ->
          if p[:id] == player_id do
            Map.put(p, :movement, {offset_x / 1, offset_y / 1})
          else
            p
          end
        end)
      end)

    {:reply, new_state, new_state}
  end

  def handle_call({:new_player}, _from, state) do
    player_number = Enum.count(state[:players]) + 1

    new_state =
      Map.update!(state, :players, fn players ->
        players ++
          [
            %{
              :id => player_number,
              :position => {player_number / 1, 0.0},
              :lin_vel => {0.0, 0.0},
              :movement => {0.0, 0.0}
            }
          ]
      end)

    {:reply, player_number, new_state}
  end
end
