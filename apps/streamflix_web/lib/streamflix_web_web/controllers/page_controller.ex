defmodule StreamflixWebWeb.PageController do
  use StreamflixWebWeb, :controller

  def home(conn, _params) do
    pricing = %{
      basic: 0,
      standard: 0,
      premium: 0
    }
    render(conn, :home, pricing: pricing)
  end

  def login(conn, _params) do
    render(conn, :login)
  end

  def signup(conn, params) do
    plan = Map.get(params, "plan", "standard")
    email = Map.get(params, "email", "")
    render(conn, :signup, plan: plan, email: email)
  end

  def docs(conn, _params) do
    base_url = build_base_url(conn)
    current_user = current_user_from_session(conn)
    render(conn, :docs, base_url: base_url, current_user: current_user)
  end

  defp build_base_url(conn) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    port = conn.port
    port_str = if (scheme == "https" and port == 443) or (scheme == "http" and port == 80), do: "", else: ":#{port}"
    "#{scheme}://#{conn.host}#{port_str}"
  end

  defp current_user_from_session(conn) do
    case get_session(conn, :user_token) do
      nil -> nil
      token ->
        case StreamflixAccounts.verify_token(token) do
          {:ok, user, _claims} -> user
          {:error, _} -> nil
        end
    end
  end
end
