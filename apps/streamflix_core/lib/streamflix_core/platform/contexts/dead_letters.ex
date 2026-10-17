defmodule StreamflixCore.Platform.DeadLetters do
  @moduledoc """
  Dead letter queue management: create, list, resolve, retry.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{DeadLetter, Delivery}

  # One open entry per delivery: a delivery that is dead-lettered again (e.g.
  # retried and failed once more) updates its entry instead of duplicating it.
  def create_dead_letter(attrs) do
    delivery_id = attrs[:delivery_id] || attrs["delivery_id"]

    existing =
      delivery_id &&
        Repo.one(
          from(d in DeadLetter,
            where: d.delivery_id == ^delivery_id and d.resolved == false,
            limit: 1
          )
        )

    (existing || %DeadLetter{})
    |> DeadLetter.changeset(attrs)
    |> Repo.insert_or_update()
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

  def get_dead_letter(id), do: Repo.get_uuid(DeadLetter, id) |> Repo.preload([:webhook, :event])

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
    case Repo.get_uuid(DeadLetter, id) |> Repo.preload([:event, :webhook]) do
      nil ->
        {:error, :not_found}

      dl ->
        webhook = dl.webhook

        cond do
          is_nil(webhook) or webhook.status == "inactive" ->
            {:error, :webhook_inactive}

          not (is_nil(modified_payload) or is_map(modified_payload)) ->
            {:error, :invalid_payload}

          true ->
            payload = modified_payload || dl.original_payload
            # Only carry an override when it differs from the stored event payload
            override = if dl.event && payload == dl.event.payload, do: nil, else: payload

            with {:ok, delivery} <-
                   %Delivery{}
                   |> Delivery.changeset(%{
                     event_id: dl.event_id,
                     webhook_id: dl.webhook_id,
                     status: "pending",
                     attempt_number: 0,
                     payload_override: override
                   })
                   |> Repo.insert(),
                 {:ok, _job} <-
                   Oban.insert(
                     StreamflixCore.Platform.ObanDeliveryWorker.new(%{
                       delivery_id: delivery.id,
                       retry_config: webhook.retry_config || %{}
                     })
                   ) do
              resolve_dead_letter(id)
              {:ok, delivery}
            end
        end
    end
  end
end
