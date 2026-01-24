defmodule StreamflixWebWeb.PageController do
  use StreamflixWebWeb, :controller

  alias StreamflixCore.Settings

  def home(conn, _params) do
    pricing = %{
      basic: Settings.get_plan_price("basic"),
      standard: Settings.get_plan_price("standard"),
      premium: Settings.get_plan_price("premium")
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
end
