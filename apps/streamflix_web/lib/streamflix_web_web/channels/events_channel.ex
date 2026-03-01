defmodule StreamflixWebWeb.EventsChannel do
  use Phoenix.Channel

  @impl true
  def join("events:" <> project_id, _payload, socket) do
    if socket.assigns.current_project.id == project_id do
      Phoenix.PubSub.subscribe(StreamflixCore.PubSub, "project:#{project_id}")
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info({:event_created, event}, socket) do
    push(socket, "event:created", %{
      id: event.id,
      topic: event.topic,
      payload: event.payload,
      occurred_at: event.occurred_at
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:delivery_updated, delivery}, socket) do
    push(socket, "delivery:updated", %{
      id: delivery.id,
      status: delivery.status,
      event_id: delivery.event_id
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}
end
