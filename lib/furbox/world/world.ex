defmodule Furbox.World do
  use GenServer

  @initial_world_state %{
    :players => [
      %{
        :name => "Rodo",
        :position => [0, 2]
      },
      %{
        :name => "Loro",
        :position => [0, -2]
      }
    ]
  }

  # Client
  def start_link(_default) do
    IO.inspect("Starting world")
    GenServer.start_link(__MODULE__, @initial_world_state, name: FurboxWorld)
  end

  def get_state() do
    GenServer.call(FurboxWorld, :get_state)
  end

  def move_player(player, position_offset) do
    GenServer.call(FurboxWorld, {:move_player, player, position_offset})
    broadcast_game_changed()
  end

  defp broadcast_game_changed() do
    # MyAppWeb.Endpoint.broadcast!("room:" <> rid, "new_msg", %{uid: uid, body: body})
    state = GenServer.call(FurboxWorld, :get_state)
    FurboxWeb.Endpoint.broadcast("furbox:main", "game_changed", state)
  end

  # Server (callbacks)
  @impl true
  def init(arg) do
    {:ok, arg}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:move_player, player, [offset_x, offset_y]}, _from, state) do
    new_state =
      Map.update!(state, :players, fn players ->
        Enum.map(players, fn p ->
          if p[:name] == player do
            Map.update!(p, :position, fn [x, y] ->
              [x + offset_x, y + offset_y]
            end)
          else
            p
          end
        end)
      end)

    {:reply, new_state, new_state}
  end
end
