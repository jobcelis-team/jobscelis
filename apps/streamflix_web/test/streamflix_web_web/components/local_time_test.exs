defmodule StreamflixWebWeb.LocalTimeTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import StreamflixWebWeb.CoreComponents, only: [local_time: 1]

  defp render(value, format \\ "datetime") do
    assigns = %{value: value, format: format}
    rendered_to_string(~H"<.local_time value={@value} format={@format} />")
  end

  test "renders an explicit UTC fallback and an ISO datetime with Z" do
    html = render(~U[2026-10-17 17:24:44.123456Z])

    assert html =~ ~s(datetime="2026-10-17T17:24:44.123456Z")
    assert html =~ ~s(data-local-time="datetime")
    assert html =~ "2026-10-17 17:24:44 UTC"
  end

  test "naive datetimes are treated as UTC" do
    html = render(~N[2026-10-17 17:24:44])
    assert html =~ ~s(datetime="2026-10-17T17:24:44Z")
  end

  test "date and short formats" do
    assert render(~U[2026-10-17 17:24:44Z], "date") =~ "2026-10-17 UTC"
    assert render(~U[2026-10-17 17:24:44Z], "datetime_short") =~ "2026-10-17 17:24 UTC"
  end

  test "nil renders a dash" do
    assert render(nil) =~ "—"
  end
end
