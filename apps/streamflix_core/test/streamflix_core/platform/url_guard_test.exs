defmodule StreamflixCore.Platform.UrlGuardTest do
  use StreamflixCore.DataCase, async: false

  alias StreamflixCore.Platform.UrlGuard
  alias StreamflixCore.Platform.ObanDeliveryWorker
  alias StreamflixCore.Schemas.{DeadLetter, Delivery}

  setup do
    previous = Application.get_env(:streamflix_core, :allow_private_destinations)
    Application.put_env(:streamflix_core, :allow_private_destinations, false)

    on_exit(fn ->
      Application.put_env(:streamflix_core, :allow_private_destinations, previous)
    end)
  end

  describe "check/1" do
    test "rejects loopback, private, link-local (cloud metadata) and IPv6 internal" do
      for url <- [
            "http://127.0.0.1/x",
            "http://localhost:4000/",
            "http://10.0.0.5/",
            "http://172.20.1.1/",
            "http://192.168.1.10/",
            "http://169.254.169.254/latest/meta-data/",
            "http://100.64.0.1/",
            "http://0.0.0.0/",
            "http://[::1]/",
            "http://[fd00::1]/",
            "http://[fe80::1]/",
            "http://[::ffff:127.0.0.1]/"
          ] do
        assert {:error, :private_address} = UrlGuard.check(url), url
      end
    end

    test "accepts public addresses" do
      assert :ok = UrlGuard.check("https://8.8.8.8/hook")
      assert :ok = UrlGuard.check("http://[2606:4700:4700::1111]/hook")
    end

    test "rejects non-http schemes and garbage" do
      assert {:error, :unsupported_scheme} = UrlGuard.check("file:///etc/passwd")
      assert {:error, :unsupported_scheme} = UrlGuard.check("gopher://127.0.0.1/")
      assert {:error, :invalid_url} = UrlGuard.check("not a url")
      assert {:error, :invalid_url} = UrlGuard.check(nil)
    end
  end

  test "webhooks cannot be saved with an internal URL" do
    project = insert(:project)

    assert {:error, changeset} =
             StreamflixCore.Platform.create_webhook(project.id, %{
               "url" => "http://169.254.169.254/metadata"
             })

    assert %{url: [_]} = Ecto.Changeset.traverse_errors(changeset, fn {m, _} -> m end)
  end

  test "deliveries to a now-internal destination are blocked and dead-lettered" do
    project = insert(:project)
    # Inserted directly (bypassing validation), as if DNS changed after saving
    webhook = insert(:webhook, project_id: project.id, url: "http://127.0.0.1:1/hook")
    event = insert(:webhook_event, project_id: project.id)
    delivery = insert(:delivery, event_id: event.id, webhook_id: webhook.id)

    assert {:cancel, :dead_lettered} =
             ObanDeliveryWorker.perform(%Oban.Job{args: %{"delivery_id" => delivery.id}})

    assert %{status: "failed", response_body: "blocked: destination " <> _} =
             Repo.get(Delivery, delivery.id)

    assert Repo.get_by(DeadLetter, delivery_id: delivery.id)
  end
end
