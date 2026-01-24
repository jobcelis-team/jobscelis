defmodule StreamflixWebWeb.PageController do
  use StreamflixWebWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def login(conn, _params) do
    render(conn, :login)
  end

  def signup(conn, params) do
    plan = Map.get(params, "plan", "standard")
    email = Map.get(params, "email", "")
    render(conn, :signup, plan: plan, email: email)
  end
end
