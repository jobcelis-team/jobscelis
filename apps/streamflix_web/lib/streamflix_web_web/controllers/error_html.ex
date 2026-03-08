defmodule StreamflixWebWeb.ErrorHTML do
  @moduledoc """
  Custom error pages for HTML requests (404, 500, etc.).
  Detects locale from the `locale` cookie via raw headers.
  """
  use StreamflixWebWeb, :html

  embed_templates "error_html/*"

  def locale(%Plug.Conn{} = conn) do
    cookie_header =
      conn
      |> Plug.Conn.get_req_header("cookie")
      |> List.first("")

    case Regex.run(~r/locale=(es|en)/, cookie_header) do
      [_, lang] -> lang
      _ -> "en"
    end
  rescue
    _ -> "en"
  end

  def locale(_), do: "en"

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
