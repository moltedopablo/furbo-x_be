defmodule Furbox.World do
  use GenServer

  # @ball_size 1.0
  # @player_size 1.0
  @close_enough 3.0

  @initial_world_state %{
    :ball => %{
      :position => {0.0, 0.0},
      :lin_vel => {0.0, 0.0},
      :shoot_dir => {0.0, 0.0},
      :scale => 1.0
    },
    :players => []
  }

  @court_dimensions %{:width => 100.0, :height => 50.0, :goal_width => 12.0, :goal_depth => 6.0}

  # Client fn
  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(_default) do
    IO.inspect("Starting world")
    GenServer.start_link(__MODULE__, @initial_world_state, name: FurboxWorld)
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

  def new_player(channel_pid) do
    GenServer.call(FurboxWorld, {:new_player, channel_pid})
  end

  def player_disconnected(channel_pid) do
    GenServer.call(FurboxWorld, {:player_disconnected, channel_pid})
  end

  def kick(player) do
    GenServer.call(FurboxWorld, {:kick, player})
  end

  # Server (callbacks)
  @impl true
  def init(arg) do
    {:ok, arg}
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

  def handle_call({:new_player, channel_pid}, _from, state) do
    player_number = Enum.count(state[:players]) + 1

    new_state =
      Map.update!(state, :players, fn players ->
        players ++
          [
            %{
              :id => player_number,
              :channel_pid => channel_pid,
              :position => {player_number / 1, 0.0},
              :lin_vel => {0.0, 0.0},
              :movement => {0.0, 0.0},
              :scale => 1.4
            }
          ]
      end)

    {:reply, player_number, new_state}
  end

  def handle_call({:player_disconnected, channel_pid}, _from, state) do
    new_state =
      Map.update!(state, :players, fn players ->
        Enum.filter(players, fn p -> p[:channel_pid] != channel_pid end)
      end)

    {:reply, new_state, new_state}
  end

  def handle_call({:kick, player_id}, _from, state) do
    player = get_player(player_id, state)
    # If player is close enough to the ball, kick it
    {ball_x, ball_y} = state[:ball] |> Map.get(:position)
    {player_x, player_y} = player |> Map.get(:position)

    if :math.pow(ball_x - player_x, 2) + :math.pow(ball_y - player_y, 2) <
         :math.pow(@close_enough, 2) do
      # Calculate the direction of the kick creating a vector with the position of the player an the ball
      direction_x = ball_x - player_x
      direction_y = ball_y - player_y
      magnitude = :math.sqrt(:math.pow(direction_x, 2) + :math.pow(direction_y, 2))
      normalized_direction = {direction_x / magnitude, direction_y / magnitude}
      {shoot_dir_x, shoot_dir_y} = normalized_direction
      new_ball = Map.put(state[:ball], :shoot_dir, {shoot_dir_x, shoot_dir_y})
      new_state = Map.put(state, :ball, new_ball)
      {:reply, new_state, new_state}
    else
      {:reply, state, state}
    end
  end

  defp clean_state(state) do
    # JSON Encoder doesn't like tuples
    %{
      ball: %{position: [state.ball.position |> elem(0), state.ball.position |> elem(1)]},
      players:
        Enum.map(state.players, fn p ->
          %{id: p.id, position: [p.position |> elem(0), p.position |> elem(1)], scale: p.scale}
        end)
    }
  end

  defp get_player(player_id, state) do
    state[:players] |> Enum.find(fn p -> p[:id] == player_id end)
  end

  def get_court_dimensions() do
    @court_dimensions
  end

  defp step(state) do
    {new_ball, new_players} =
      RapierEx.step(
        state.ball,
        @court_dimensions,
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

    FurboxWeb.Endpoint.broadcast("furbox:main", "game_changed", new_state |> clean_state)
    {:ok, new_state}
  end
end
