defmodule StreamflixCore do
  @moduledoc """
  Core for Webhooks + Events platform: Repo, PubSub, Platform (projects, events, webhooks, jobs), Oban.
  """

  def generate_id, do: UUID.uuid4()
  def now, do: DateTime.utc_now()

  def broadcast(topic, event) do
    Phoenix.PubSub.broadcast(StreamflixCore.PubSub, topic, event)
  end

  def subscribe(topic) do
    Phoenix.PubSub.subscribe(StreamflixCore.PubSub, topic)
  end
end
