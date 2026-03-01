defmodule StreamflixCore.Factory do
  use ExMachina.Ecto, repo: StreamflixCore.Repo

  alias StreamflixCore.Schemas.{Project, WebhookEvent, Webhook, Delivery}

  def project_factory() do
    %Project{
      id: Ecto.UUID.generate(),
      name: sequence(:project_name, &"Test Project #{&1}"),
      status: "active",
      is_default: false,
      settings: %{}
    }
  end

  def webhook_event_factory() do
    %WebhookEvent{
      id: Ecto.UUID.generate(),
      topic: sequence(:topic, &"test.topic.#{&1}"),
      payload: %{"key" => "value"},
      status: "active",
      occurred_at: DateTime.utc_now()
    }
  end

  def webhook_factory() do
    %Webhook{
      id: Ecto.UUID.generate(),
      url: sequence(:webhook_url, &"https://example.com/webhook/#{&1}"),
      status: "active",
      topics: ["*"],
      filters: [],
      body_config: %{},
      headers: %{},
      retry_config: %{}
    }
  end

  def delivery_factory() do
    %Delivery{
      id: Ecto.UUID.generate(),
      status: "pending",
      attempt_number: 0,
      response_status: nil,
      response_body: nil
    }
  end
end
