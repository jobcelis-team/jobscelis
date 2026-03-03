defmodule StreamflixCore.Schemas.SandboxRequest do
  @moduledoc """
  A captured HTTP request to a sandbox endpoint.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sandbox_requests" do
    field(:method, :string)
    field(:path, :string)
    field(:headers, :map, default: %{})
    field(:body, :string)
    field(:query_params, :map, default: %{})
    field(:ip, StreamflixCore.Encrypted.Binary)

    belongs_to(:endpoint, StreamflixCore.Schemas.SandboxEndpoint)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(request, attrs) do
    request
    |> cast(attrs, [:endpoint_id, :method, :path, :headers, :body, :query_params, :ip])
    |> validate_required([:endpoint_id, :method])
    |> foreign_key_constraint(:endpoint_id)
  end
end
