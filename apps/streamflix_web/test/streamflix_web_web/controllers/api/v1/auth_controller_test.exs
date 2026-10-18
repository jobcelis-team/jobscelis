defmodule StreamflixWebWeb.Api.V1.AuthControllerTest do
  use StreamflixWebWeb.ConnCase, async: false

  @password "SecurePass123!"

  setup do
    email = "auth#{System.unique_integer([:positive])}@example.com"

    {:ok, _user, _} =
      StreamflixAccounts.register_user(%{email: email, password: @password, name: "Auth"})

    %{email: email}
  end

  defp login(conn, email) do
    conn
    |> post("/api/v1/auth/login", %{email: email, password: @password})
    |> json_response(200)
    |> Map.fetch!("token")
  end

  describe "POST /api/v1/auth/login" do
    test "rejects a too-short password with an English error", %{conn: conn, email: email} do
      resp =
        conn
        |> post("/api/v1/auth/login", %{email: email, password: "short"})
        |> json_response(400)

      assert resp["error"] == "Password must be at least 8 characters"
    end
  end

  describe "POST /api/v1/auth/refresh" do
    test "accepts the token as \"token\" (docs, CLI)", %{conn: conn, email: email} do
      token = login(conn, email)
      resp = build_conn() |> post("/api/v1/auth/refresh", %{token: token}) |> json_response(200)
      assert is_binary(resp["token"])
    end

    test "accepts the token as \"refresh_token\" (SDKs)", %{conn: conn, email: email} do
      token = login(conn, email)

      resp =
        build_conn()
        |> post("/api/v1/auth/refresh", %{refresh_token: token})
        |> json_response(200)

      assert is_binary(resp["token"])
    end

    test "returns 422 when no token is sent", %{conn: conn} do
      assert conn
             |> post("/api/v1/auth/refresh", %{})
             |> json_response(422)
             |> Map.has_key?("error")
    end

    test "returns 401 for an invalid token", %{conn: conn} do
      assert conn |> post("/api/v1/auth/refresh", %{token: "nope"}) |> json_response(401)
    end
  end

  describe "POST /api/v1/auth/mfa/verify" do
    setup %{email: email} do
      user = StreamflixAccounts.get_user_by_email(email)
      {:ok, secret, _uri} = StreamflixAccounts.setup_mfa(user)

      {:ok, _user, _backup_codes} =
        StreamflixAccounts.enable_mfa(user, secret, NimbleTOTP.verification_code(secret))

      %{secret: secret}
    end

    defp mfa_challenge(conn, email) do
      resp =
        conn
        |> post("/api/v1/auth/login", %{email: email, password: @password})
        |> json_response(200)

      assert resp["mfa_required"] == true
      resp["mfa_token"]
    end

    test "accepts the challenge as \"token\" (SDKs, CLI)", %{
      conn: conn,
      email: email,
      secret: secret
    } do
      challenge = mfa_challenge(conn, email)

      resp =
        build_conn()
        |> post("/api/v1/auth/mfa/verify", %{
          token: challenge,
          code: NimbleTOTP.verification_code(secret)
        })
        |> json_response(200)

      assert is_binary(resp["token"])
    end

    test "accepts the challenge as \"mfa_token\" (docs)", %{
      conn: conn,
      email: email,
      secret: secret
    } do
      challenge = mfa_challenge(conn, email)

      resp =
        build_conn()
        |> post("/api/v1/auth/mfa/verify", %{
          mfa_token: challenge,
          code: NimbleTOTP.verification_code(secret)
        })
        |> json_response(200)

      assert is_binary(resp["token"])
    end

    test "rejects a wrong code", %{conn: conn, email: email} do
      challenge = mfa_challenge(conn, email)

      assert build_conn()
             |> post("/api/v1/auth/mfa/verify", %{token: challenge, code: "000000"})
             |> json_response(401)
    end
  end
end
