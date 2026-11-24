defmodule StreamflixCore.Repo.Migrations.StripProxyHeadersFromSandboxRequests do
  @moduledoc """
  Removes the headers added by the Cloudflare failover Worker (including the
  shared proxy secret) from sandbox requests captured before they were filtered.
  """
  use Ecto.Migration

  def up do
    execute("""
    UPDATE sandbox_requests
    SET headers = headers - 'x-jobcelis-proxy-secret' - 'x-jobcelis-client-ip'
    WHERE headers ?| array['x-jobcelis-proxy-secret', 'x-jobcelis-client-ip']
    """)
  end

  # The removed values must not come back
  def down, do: :ok
end
