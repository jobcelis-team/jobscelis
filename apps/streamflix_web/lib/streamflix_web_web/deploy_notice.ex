defmodule StreamflixWebWeb.DeployNotice do
  @moduledoc """
  Tells everyone with a LiveView page open that the server is restarting for
  an update, so they see "we are improving Jobcelis" instead of a generic
  connection error.

  On a deploy the platform sends SIGTERM; the application stops its children
  in reverse start order. This process starts after the endpoint, so it stops
  first, while LiveView sockets are still connected: it broadcasts the notice
  and waits briefly so the message reaches the browsers.

  Enabled in production only (`config :streamflix_web, :deploy_notice`).
  """

  use GenServer

  @topic "system:deploy"
  # Time for the broadcast to reach the open sockets before the endpoint stops
  @flush_ms 1_500

  def topic, do: @topic

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, shutdown: @flush_ms + 1_000}
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    {:ok, %{flush_ms: Keyword.get(opts, :flush_ms, @flush_ms)}}
  end

  @impl true
  def terminate(_reason, %{flush_ms: flush_ms}) do
    Phoenix.PubSub.broadcast(StreamflixCore.PubSub, @topic, {:deploy_notice, :restarting})
    Process.sleep(flush_ms)
    :ok
  end

  def enabled?, do: Application.get_env(:streamflix_web, :deploy_notice, false) == true
end
