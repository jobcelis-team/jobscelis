defmodule StreamflixWebWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use StreamflixWebWeb, :html

  embed_templates "page_html/*"

  # Date the legal texts (terms, privacy, cookies) last changed.
  # Update it whenever their content changes — it must not be "today".
  @legal_updated_on ~D[2026-03-08]

  def legal_updated_on, do: @legal_updated_on
end
