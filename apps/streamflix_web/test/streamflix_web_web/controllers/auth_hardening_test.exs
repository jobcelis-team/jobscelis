defmodule StreamflixWebWeb.AuthHardeningTest do
  @moduledoc """
  Browser and API auth hardening: no user enumeration through lockout,
  malformed params answered with errors instead of crashes, MFA limits.
  """
  use StreamflixWebWeb.ConnCase, async: false

  alias StreamflixAccounts.Schemas.User
  alias StreamflixCore.Repo

  @password "SecurePass123!"

  setup %{conn: conn} do
    email = "harden#{System.unique_integer([:positive])}@example.com"

    {:ok, user, _} =
      StreamflixAccounts.register_user(%{email: email, password: @password, name: "Harden"})

    # A fresh client IP per test keeps the rate-limit buckets apart
    n = System.unique_integer([:positive])
    conn = %{conn | remote_ip: {10, 77, rem(div(n, 256), 256), rem(n, 256)}}

    %{conn: conn, user: user, email: email}
  end

  defp lock!(user) do
    user
    |> Ecto.Changeset.change(locked_at: DateTime.utc_now(), failed_login_attempts: 5)
    |> Repo.update!()
  end

  defp enable_mfa!(user) do
    {:ok, secret, _} = StreamflixAccounts.setup_mfa(user)

    {:ok, enabled, codes} =
      StreamflixAccounts.enable_mfa(user, secret, NimbleTOTP.verification_code(secret))

    on_exit(fn -> Cachex.del(:platform_cache, {:mfa_attempts, user.id}) end)
    {enabled, codes}
  end

  describe "locked accounts do not reveal that the email exists" do
    test "web login shows the generic error", %{conn: conn, user: user, email: email} do
      lock!(user)

      locked = post(conn, "/login", %{"email" => email, "password" => @password})

      unknown =
        post(conn, "/login", %{"email" => "nobody@example.com", "password" => @password})

      assert redirected_to(locked) == "/login"
      locked_msg = Phoenix.Flash.get(locked.assigns.flash, :error)
      assert locked_msg == Phoenix.Flash.get(unknown.assigns.flash, :error)
      refute locked_msg =~ "bloquead"
    end

    test "API login answers 401 like a wrong password", %{conn: conn, user: user, email: email} do
      lock!(user)

      locked =
        conn
        |> post("/api/v1/auth/login", %{email: email, password: @password})
        |> json_response(401)

      unknown =
        build_conn()
        |> Map.put(:remote_ip, conn.remote_ip)
        |> post("/api/v1/auth/login", %{email: "nobody@example.com", password: @password})
        |> json_response(401)

      assert locked == unknown
    end

    test "the lockout still blocks the right password", %{conn: conn, user: user, email: email} do
      lock!(user)
      conn = post(conn, "/login", %{"email" => email, "password" => @password})
      assert redirected_to(conn) == "/login"
      refute get_session(conn, :user_token)
    end
  end

  describe "restricted accounts" do
    test "can log in through the API", %{conn: conn, user: user, email: email} do
      {:ok, _} = StreamflixAccounts.restrict_user(user, @password)

      resp =
        conn
        |> post("/api/v1/auth/login", %{email: email, password: @password})
        |> json_response(200)

      assert is_binary(resp["token"])
    end
  end

  describe "API signup errors" do
    test "a registered email is a 422, not a 500", %{conn: conn, email: email} do
      resp =
        conn
        |> post("/api/v1/auth/register", %{email: email, password: @password, name: "Dup"})
        |> json_response(422)

      assert resp["errors"]["email"]
      refute Map.has_key?(resp, "details")
    end
  end

  describe "FallbackController" do
    test "unknown errors never leak inspect output", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_private(:phoenix_format, "json")
        |> StreamflixWebWeb.FallbackController.call({:error, {:secret, "internal-detail"}})

      body = json_response(conn, 500)
      assert body == %{"error" => "Internal server error"}
    end
  end

  describe "malformed params" do
    test "API login with object email/password is a 400", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/login", %{
          "email" => %{"a" => "b"},
          "password" => %{"c" => "d"}
        })

      assert json_response(conn, 400)["error"]
    end

    test "API signup with an object name is a 400", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/register", %{
          "email" => "x#{System.unique_integer([:positive])}@example.com",
          "password" => @password,
          "name" => %{"a" => "b"}
        })

      assert json_response(conn, 400)["error"]
    end

    test "API MFA verify with a non-string code is a 400", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/mfa/verify", %{"mfa_token" => "x", "code" => %{"a" => 1}})
      assert json_response(conn, 400)["error"]
    end

    test "web login with nested params shows the normal error", %{conn: conn} do
      conn = post(conn, "/login", %{"email" => %{"a" => "b"}, "password" => ["x"]})
      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "web signup with nested params shows the normal error", %{conn: conn} do
      conn =
        post(conn, "/signup", %{
          "email" => %{"a" => "b"},
          "password" => @password,
          "name" => %{"x" => 1},
          "plan" => %{"y" => 2}
        })

      assert redirected_to(conn) =~ "/signup"
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "web MFA verify with a non-string code does not crash", %{conn: conn, user: user} do
      {user, _} = enable_mfa!(user)

      session = %{mfa_user_id: user.id, mfa_started_at: System.system_time(:second)}
      conn = conn |> init_test_session(session) |> post("/mfa/verify", %{"code" => %{"a" => 1}})
      assert redirected_to(conn) == "/mfa/verify"

      conn =
        build_conn()
        |> init_test_session(session)
        |> post("/mfa/verify-backup", %{"code" => ["x"]})

      assert redirected_to(conn) == "/mfa/verify"
    end
  end

  describe "web MFA backup codes" do
    test "share the TOTP attempt limit", %{conn: conn, user: user} do
      {user, [code | _]} = enable_mfa!(user)
      session = %{mfa_user_id: user.id, mfa_started_at: System.system_time(:second)}

      for _ <- 1..4 do
        resp = conn |> init_test_session(session) |> post("/mfa/verify-backup", %{"code" => "x"})
        assert redirected_to(resp) == "/mfa/verify"
      end

      resp = conn |> init_test_session(session) |> post("/mfa/verify-backup", %{"code" => "x"})
      assert redirected_to(resp) == "/login"

      # A valid code no longer logs in once the limit is reached (from another
      # IP: the per-IP rate limit for this path is reached too)
      resp =
        conn
        |> Map.put(:remote_ip, {10, 78, 0, 1})
        |> init_test_session(session)
        |> post("/mfa/verify-backup", %{"code" => code})

      assert redirected_to(resp) == "/login"
      refute get_session(resp, :user_token)
    end
  end

  describe "password reset" do
    test "rejects passwords over 72 bytes before touching the token", %{conn: conn, user: user} do
      {:ok, token, _} = StreamflixAccounts.generate_reset_password_token(user.email)
      long = "Aa1" <> String.duplicate("x", 100)

      conn =
        post(conn, "/reset-password/#{token}", %{
          "password" => long,
          "password_confirm" => long
        })

      assert redirected_to(conn) == "/reset-password/#{token}"
      assert {:ok, _} = StreamflixAccounts.verify_reset_password_token(token)
      assert Repo.get!(User, user.id).password_hash == user.password_hash
    end
  end
end
