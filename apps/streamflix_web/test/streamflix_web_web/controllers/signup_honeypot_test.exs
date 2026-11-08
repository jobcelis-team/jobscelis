defmodule StreamflixWebWeb.SignupHoneypotTest do
  use StreamflixWebWeb.ConnCase, async: false

  @password "SecurePass123!"

  defp signup(conn, params) do
    conn
    |> Map.put(:remote_ip, {10, 0, 0, Enum.random(1..250)})
    |> post("/signup", Map.merge(%{"name" => "Ana", "password" => @password}, params))
  end

  test "rejects the signup when the hidden honeypot field is filled", %{conn: conn} do
    email = "bot#{System.unique_integer([:positive])}@example.com"
    conn = signup(conn, %{"email" => email, "website" => "http://spam.example"})

    assert Phoenix.Flash.get(conn.assigns.flash, :error)
    assert StreamflixAccounts.get_user_by_email(email) == nil
  end

  test "an empty honeypot field does not block a real signup", %{conn: conn} do
    email = "ana#{System.unique_integer([:positive])}@example.com"
    _conn = signup(conn, %{"email" => email, "website" => ""})

    assert StreamflixAccounts.get_user_by_email(email)
  end

  test "the signup form renders the hidden honeypot field", %{conn: conn} do
    html = conn |> get("/signup") |> html_response(200)
    assert html =~ ~s(name="website")
    assert html =~ ~s(tabindex="-1")
  end
end
