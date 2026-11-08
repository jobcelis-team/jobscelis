defmodule StreamflixWebWeb.BrowserExportControllerTest do
  use StreamflixWebWeb.ConnCase, async: false

  setup %{conn: conn} do
    {:ok, user, _} =
      StreamflixAccounts.register_user(%{
        email: "export#{System.unique_integer([:positive])}@example.com",
        password: "SecurePass123!",
        name: "Export User"
      })

    {:ok, token, claims} = StreamflixAccounts.generate_token(user)
    {:ok, _} = StreamflixAccounts.create_session(user.id, claims["jti"])

    conn =
      init_test_session(conn, %{user_token: token, current_jti: claims["jti"], remember_me: true})

    %{conn: conn, user: user}
  end

  test "exports the selected project and neutralizes formulas", %{conn: conn, user: user} do
    selected = insert(:project, user_id: user.id)
    insert(:job, project_id: selected.id, name: "=cmd|'/C calc'!A0")

    other = insert(:project)
    insert(:job, project_id: other.id, name: "foreign job")

    body = conn |> get("/export/jobs?format=csv&project=#{selected.id}") |> response(200)
    assert body =~ "'=cmd|'/C calc'!A0"

    # A project the user cannot access is ignored
    body = conn |> get("/export/jobs?format=csv&project=#{other.id}") |> response(200)
    refute body =~ "foreign job"
  end
end
