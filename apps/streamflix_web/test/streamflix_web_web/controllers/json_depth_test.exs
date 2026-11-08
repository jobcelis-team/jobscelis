defmodule StreamflixWebWeb.JsonDepthTest do
  use StreamflixWebWeb.ConnCase, async: true

  # 240 KB of brackets fits under the body size limit but is ~120k levels
  # deep; stored as jsonb, PostgreSQL would fail with "stack depth limit
  # exceeded". The parser must reject it as a bad request instead.
  test "deeply nested JSON bodies are rejected with 400", %{conn: conn} do
    n = 120_000

    body =
      ~s({"topic":"deep.t","x":) <> String.duplicate("[", n) <> String.duplicate("]", n) <> "}"

    assert {400, _, _} =
             assert_error_sent(400, fn ->
               conn
               |> put_req_header("content-type", "application/json")
               |> post("/api/v1/send", body)
             end)
  end
end
