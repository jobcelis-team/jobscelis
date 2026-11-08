defmodule StreamflixWebWeb.PlatformDashboard.HelpersTest do
  use ExUnit.Case, async: true

  alias StreamflixWebWeb.PlatformDashboard.Helpers

  defp changeset(errors), do: %Ecto.Changeset{errors: errors, valid?: false}

  test "names the first validation problem, translated" do
    Gettext.put_locale(StreamflixWebWeb.Gettext, "es")

    error =
      {"should be at most %{count} character(s)", [count: 100, validation: :length, kind: :max]}

    assert Helpers.create_error_message(changeset(name: error), "Error al crear proyecto.") ==
             "Error al crear proyecto. name: debe tener como máximo 100 caracteres"
  end

  test "falls back to the default message" do
    assert Helpers.create_error_message(changeset([]), "Error.") == "Error."
    assert Helpers.create_error_message(:timeout, "Error.") == "Error."
  end
end
