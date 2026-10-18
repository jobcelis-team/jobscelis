defmodule StreamflixWebWeb.Plugs.RequireScopeTest do
  use ExUnit.Case, async: true

  import Plug.Test
  alias StreamflixWebWeb.Plugs.RequireScope

  defp call(scopes, required) do
    conn(:post, "/api/v1/events")
    |> Plug.Conn.assign(:current_api_key, %{scopes: scopes})
    |> RequireScope.call(required)
  end

  test "lets keys with the scope (or *) through" do
    refute call(["events:write"], "events:write").halted
    refute call(["*"], "webhooks:write").halted
  end

  test "rejects keys without the scope, naming it" do
    conn = call(["events:read"], "events:write")
    assert conn.halted
    assert conn.status == 403

    assert Jason.decode!(conn.resp_body) == %{
             "error" => "API key is missing the events:write scope"
           }
  end
end
