defmodule FurboxWeb.WorldChannel do
  use FurboxWeb, :channel

  @impl true
  def join("furbox:main", payload, socket) do
    if authorized?(payload) do
      player_id = Furbox.World.new_player()
      court_dimensions = Furbox.World.get_court_dimensions()
      {:ok, %{:player_id => player_id, :court_dimensions => court_dimensions}, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("get_state", _payload, socket) do
    payload = Furbox.World.get_state()
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (world:lobby).
  @impl true
  def handle_in("move_player", %{"offset" => [offset_x, offset_y], "player" => player}, socket) do
    Furbox.World.move_player(player, [offset_x, offset_y])
    {:noreply, socket}
  end

  def handle_in("kick", %{"player" => player}, socket) do
    Furbox.World.kick(player)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
