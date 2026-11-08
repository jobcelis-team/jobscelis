defmodule StreamflixWebWeb.DeployNoticeHook do
  @moduledoc """
  on_mount hook: connected LiveViews listen for `StreamflixWebWeb.DeployNotice`
  and forward it to the browser. The notice itself is rendered (translated)
  in the root layout; app.js shows it.
  """

  import Phoenix.LiveView

  alias StreamflixWebWeb.DeployNotice

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(StreamflixCore.PubSub, DeployNotice.topic())
      {:cont, attach_hook(socket, :deploy_notice, :handle_info, &handle_info/2)}
    else
      {:cont, socket}
    end
  end

  defp handle_info({:deploy_notice, :restarting}, socket) do
    {:halt, push_event(socket, "deploy-notice", %{})}
  end

  defp handle_info(_message, socket), do: {:cont, socket}
end
