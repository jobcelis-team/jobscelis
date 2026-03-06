defmodule StreamflixCore.Platform.DeadLetters do
  @moduledoc """
  Dead letter queue management: create, list, resolve, retry.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{DeadLetter, Delivery}

  def create_dead_letter(attrs) do
    %DeadLetter{}
    |> DeadLetter.changeset(attrs)
    |> Repo.insert()
  end

  def list_dead_letters(project_id, opts \\ []) do
    resolved = Keyword.get(opts, :resolved, false)
    limit = Keyword.get(opts, :limit, 50)

    DeadLetter
    |> where([dl], dl.project_id == ^project_id and dl.resolved == ^resolved)
    |> order_by([dl], desc: dl.inserted_at)
    |> limit(^limit)
    |> preload([:webhook, :event])
    |> Repo.all()
  end

  def get_dead_letter(id), do: Repo.get(DeadLetter, id) |> Repo.preload([:webhook, :event])

  def resolve_dead_letter(id) do
    case Repo.get(DeadLetter, id) do
      nil ->
        {:error, :not_found}

      dl ->
        dl
        |> DeadLetter.changeset(%{
          resolved: true,
          resolved_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
        })
        |> Repo.update()
    end
  end

  def retry_dead_letter(id, modified_payload \\ nil) do
    case Repo.get(DeadLetter, id) |> Repo.preload([:event, :webhook]) do
      nil ->
        {:error, :not_found}

      dl ->
        _payload = modified_payload || dl.original_payload
        webhook = dl.webhook

        if is_nil(webhook) or webhook.status == "inactive" do
          {:error, :webhook_inactive}
        else
          case %Delivery{}
               |> Delivery.changeset(%{
                 event_id: dl.event_id,
                 webhook_id: dl.webhook_id,
                 status: "pending",
                 attempt_number: 0
               })
               |> Repo.insert() do
            {:ok, delivery} ->
              Oban.insert(
                StreamflixCore.Platform.ObanDeliveryWorker.new(%{delivery_id: delivery.id})
              )

              resolve_dead_letter(id)
              {:ok, delivery}

            error ->
              error
          end
        end
    end
  end
end
