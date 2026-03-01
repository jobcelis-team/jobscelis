defmodule StreamflixWebWeb.UserSocket do
  use Phoenix.Socket

  channel "events:*", StreamflixWebWeb.EventsChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case StreamflixCore.Platform.verify_api_key("", token) do
      nil ->
        :error

      api_key ->
        scopes = api_key.scopes || ["*"]

        if "*" in scopes or "events:read" in scopes do
          socket =
            socket
            |> assign(:current_api_key, api_key)
            |> assign(:current_project, api_key.project)

          {:ok, socket}
        else
          :error
        end
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_project.id}"
end
