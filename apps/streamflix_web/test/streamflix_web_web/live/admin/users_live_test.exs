defmodule StreamflixWebWeb.Admin.UsersLiveTest do
  use StreamflixWebWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias StreamflixAccounts.Schemas.User
  alias StreamflixCore.Repo

  defp register(name, role \\ "user") do
    {:ok, user, _} =
      StreamflixAccounts.register_user(%{
        email: "#{name}#{System.unique_integer([:positive])}@example.com",
        password: "SecurePass123!",
        name: "Admin Test"
      })

    user
    |> Ecto.Changeset.change(%{
      role: role,
      email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update!()
  end

  defp login(conn, user) do
    {:ok, token, claims} = StreamflixAccounts.generate_token(user)
    {:ok, _} = StreamflixAccounts.create_session(user.id, claims["jti"])

    Phoenix.ConnTest.init_test_session(conn, %{
      user_token: token,
      current_jti: claims["jti"],
      remember_me: true
    })
  end

  defp save_params(user, overrides) do
    Map.merge(
      %{
        "_id" => user.id,
        "name" => user.name,
        "email" => user.email,
        "role" => user.role,
        "status" => user.status
      },
      overrides
    )
  end

  defp reload(user), do: Repo.get!(User, user.id)

  setup do
    Cachex.clear(:platform_cache)
    :ok
  end

  test "an admin cannot modify a superadmin", %{conn: conn} do
    admin = register("admin", "admin")
    superadmin = register("super", "superadmin")
    {:ok, view, _} = live(login(conn, admin), "/admin/users")

    render_hook(
      view,
      "save_user",
      save_params(superadmin, %{"email" => "taken#{System.unique_integer([:positive])}@x.com"})
    )

    assert reload(superadmin).email == superadmin.email

    render_hook(view, "deactivate_user", %{"id" => superadmin.id})
    assert reload(superadmin).status == "active"
  end

  test "an admin cannot grant admin roles", %{conn: conn} do
    admin = register("admin", "admin")
    user = register("plain")
    {:ok, view, _} = live(login(conn, admin), "/admin/users")

    render_hook(view, "save_user", save_params(user, %{"role" => "admin"}))
    assert reload(user).role == "user"
  end

  test "nobody can change their own role or status", %{conn: conn} do
    superadmin = register("super", "superadmin")
    {:ok, view, _} = live(login(conn, superadmin), "/admin/users")

    render_hook(view, "save_user", save_params(superadmin, %{"role" => "user"}))
    assert reload(superadmin).role == "superadmin"

    render_hook(view, "deactivate_user", %{"id" => superadmin.id})
    assert reload(superadmin).status == "active"
  end

  test "changing the email resets verification and deactivating revokes sessions", %{conn: conn} do
    superadmin = register("super", "superadmin")
    user = register("plain")
    {:ok, _token, claims} = StreamflixAccounts.generate_token(user)
    {:ok, _} = StreamflixAccounts.create_session(user.id, claims["jti"])

    {:ok, view, _} = live(login(conn, superadmin), "/admin/users")
    new_email = "changed#{System.unique_integer([:positive])}@example.com"

    render_hook(
      view,
      "save_user",
      save_params(user, %{"email" => new_email, "status" => "inactive"})
    )

    updated = reload(user)
    assert updated.email == new_email
    assert is_nil(updated.email_verified_at)
    assert updated.status == "inactive"
    assert StreamflixAccounts.list_sessions(user.id) == []
  end

  test "a demoted admin can no longer act", %{conn: conn} do
    admin = register("admin", "admin")
    user = register("plain")
    {:ok, view, _} = live(login(conn, admin), "/admin/users")

    admin |> Ecto.Changeset.change(%{role: "user"}) |> Repo.update!()

    assert {:error, {:redirect, %{to: "/"}}} =
             render_hook(view, "deactivate_user", %{"id" => user.id})

    assert reload(user).status == "active"
  end
end
