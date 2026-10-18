defmodule StreamflixWebWeb.Api.V1.PlatformProjectsControllerTest do
  use StreamflixWebWeb.ConnCase, async: false

  defp jwt_conn(conn) do
    {:ok, user, _} =
      StreamflixAccounts.register_user(%{
        email: "proj#{System.unique_integer([:positive])}@example.com",
        password: "SecurePass123!",
        name: "Projects"
      })

    {:ok, token, claims} = StreamflixAccounts.generate_token(user)
    {:ok, _} = StreamflixAccounts.create_session(user.id, claims["jti"])
    {put_req_header(conn, "authorization", "Bearer " <> token), user}
  end

  describe "GET /api/v1/projects" do
    test "includes projects shared with the user through a team", %{conn: conn} do
      {conn, member} = jwt_conn(conn)
      shared = insert(:project, user_id: create_test_user().id, name: "Shared with me")
      {:ok, m} = StreamflixCore.Teams.invite_member(shared.id, member.id, "editor")
      {:ok, _} = StreamflixCore.Teams.accept_invitation(m.id)

      names =
        conn
        |> get("/api/v1/projects")
        |> json_response(200)
        |> Map.fetch!("data")
        |> Enum.map(& &1["name"])

      assert "Shared with me" in names
    end

    test "does not include projects with a pending invitation", %{conn: conn} do
      {conn, member} = jwt_conn(conn)
      other = insert(:project, user_id: create_test_user().id, name: "Pending invite")
      {:ok, _} = StreamflixCore.Teams.invite_member(other.id, member.id, "viewer")

      names =
        conn
        |> get("/api/v1/projects")
        |> json_response(200)
        |> Map.fetch!("data")
        |> Enum.map(& &1["name"])

      refute "Pending invite" in names
    end
  end
end
