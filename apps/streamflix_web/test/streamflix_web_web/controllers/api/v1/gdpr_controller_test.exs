defmodule StreamflixWebWeb.Api.V1.GDPRControllerTest do
  use StreamflixWebWeb.ConnCase, async: false

  setup %{conn: conn} do
    {:ok, user, _} =
      StreamflixAccounts.register_user(%{
        email: "gdpr#{System.unique_integer([:positive])}@example.com",
        password: "SecurePass123!",
        name: "GDPR User"
      })

    {:ok, token, claims} = StreamflixAccounts.generate_token(user)
    {:ok, _} = StreamflixAccounts.create_session(user.id, claims["jti"])
    %{conn: put_req_header(conn, "authorization", "Bearer " <> token), user: user}
  end

  test "GET /me/consents works for the authenticated user", %{conn: conn} do
    assert %{} = conn |> get("/api/v1/me/consents") |> json_response(200)
  end

  test "GET /me/data exports the authenticated user's data", %{conn: conn, user: user} do
    body = conn |> get("/api/v1/me/data") |> json_response(200)
    assert body |> inspect() =~ user.id
  end

  test "unknown consent purpose is a 422, not a crash", %{conn: conn} do
    assert conn |> post("/api/v1/me/consents/not-a-purpose/accept") |> json_response(422)
  end

  test "an MFA challenge token cannot call JWT endpoints", %{user: user} do
    {:ok, mfa_token, _} =
      StreamflixAccounts.Guardian.encode_and_sign(user, %{"type" => "mfa_challenge"},
        ttl: {5, :minute}
      )

    conn = build_conn() |> put_req_header("authorization", "Bearer " <> mfa_token)
    assert conn |> get("/api/v1/me/data") |> response(401)
  end
end
