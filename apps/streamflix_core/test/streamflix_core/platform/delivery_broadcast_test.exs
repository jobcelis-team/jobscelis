defmodule StreamflixCore.Platform.DeliveryBroadcastTest do
  @moduledoc """
  Delivery updates are broadcast to every open dashboard and event stream of
  the project: they carry only what subscribers use, never the webhook (and its
  decrypted secret) or the event payload.
  """
  use StreamflixCore.DataCase, async: false

  alias StreamflixCore.Platform.DeliveryWorker
  alias StreamflixCore.RawHttpServer

  test "the broadcast payload is the delivery's id, status, event and webhook ids" do
    {port, _ref} =
      RawHttpServer.start(fn socket ->
        :gen_tcp.send(
          socket,
          "HTTP/1.1 200 OK\r\ncontent-length: 2\r\nconnection: close\r\n\r\nok"
        )
      end)

    project = insert(:project)

    webhook =
      insert(:webhook,
        project_id: project.id,
        url: "http://127.0.0.1:#{port}/hook",
        secret_encrypted: "super-secret-value"
      )

    event = insert(:webhook_event, project_id: project.id, payload: %{"card" => "4111"})
    delivery = insert(:delivery, event_id: event.id, webhook_id: webhook.id)

    Phoenix.PubSub.subscribe(StreamflixCore.PubSub, "project:#{project.id}")
    {:ok, _} = DeliveryWorker.run(delivery.id)

    assert_receive {:delivery_updated, payload}

    assert payload == %{
             id: delivery.id,
             status: "success",
             event_id: event.id,
             webhook_id: webhook.id
           }

    refute inspect(payload) =~ "super-secret-value"
    refute inspect(payload) =~ "4111"
  end
end
