defmodule StreamflixCore.Repo.Migrations.AddRequestLoggingToDeliveries do
  use Ecto.Migration

  def change do
    alter table(:deliveries) do
      add :request_headers, :map
      add :request_body, :text
      add :destination_ip, :string
    end
  end
end
