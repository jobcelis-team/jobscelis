defmodule StreamflixWebWeb.AccountLiveSecurityTest do
  use StreamflixWebWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @password "SecurePass123!"

  defp register! do
    {:ok, user, _} =
      StreamflixAccounts.register_user(%{
        email: "acct#{System.unique_integer([:positive])}@example.com",
        password: @password,
        name: "Account User"
      })

    user
  end

  setup %{conn: conn} do
    user = register!()
    {:ok, token, claims} = StreamflixAccounts.generate_token(user)
    {:ok, _} = StreamflixAccounts.create_session(user.id, claims["jti"])

    conn =
      init_test_session(conn, %{user_token: token, current_jti: claims["jti"], remember_me: true})

    %{conn: conn, user: user}
  end

  describe "consents" do
    test "cannot revoke another user's consent", %{conn: conn} do
      other = register!()
      {:ok, consent} = StreamflixCore.GDPR.grant_consent(other.id, "marketing")

      {:ok, view, _html} = live(conn, "/account")
      render_hook(view, "revoke_consent", %{"id" => consent.id})

      assert StreamflixCore.GDPR.has_consent?(other.id, "marketing")
      assert render(view)
    end

    test "a malformed consent id does not crash the view", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/account")
      render_hook(view, "revoke_consent", %{"id" => "not-a-uuid"})
      assert render(view)
    end

    test "can revoke an own consent", %{conn: conn, user: user} do
      {:ok, consent} = StreamflixCore.GDPR.grant_consent(user.id, "marketing")

      {:ok, view, _html} = live(conn, "/account")
      render_hook(view, "revoke_consent", %{"id" => consent.id})

      refute StreamflixCore.GDPR.has_consent?(user.id, "marketing")
    end

    test "re-accepting an unknown purpose does not crash the view", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/account")
      render_hook(view, "re_accept_consent", %{"purpose" => "bogus"})
      assert render(view)
    end
  end

  describe "password change" do
    test "rejects a new password over 72 bytes", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, "/account")
      long = "Aa1" <> String.duplicate("x", 100)

      render_hook(view, "save_password", %{
        "password_change" => %{
          "current_password" => @password,
          "new_password" => long,
          "new_password_confirm" => long
        }
      })

      after_user = StreamflixAccounts.get_user(user.id)
      assert after_user.password_hash == user.password_hash
    end

    test "non-string params do not crash the view", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/account")

      render_hook(view, "save_password", %{
        "password_change" => %{
          "current_password" => %{"a" => 1},
          "new_password" => ["x"],
          "new_password_confirm" => ["x"]
        }
      })

      assert render(view)
    end
  end
end
