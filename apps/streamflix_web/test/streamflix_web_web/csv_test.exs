defmodule StreamflixWebWeb.CSVTest do
  use ExUnit.Case, async: true

  alias StreamflixWebWeb.CSV

  test "neutralizes values a spreadsheet would run as formulas" do
    assert CSV.escape("=HYPERLINK(\"http://x\")") == "\"'=HYPERLINK(\"\"http://x\"\")\""
    assert CSV.escape("+1+1") == "'+1+1"
    assert CSV.escape("-2+3") == "'-2+3"
    assert CSV.escape("@SUM(A1)") == "'@SUM(A1)"
    assert CSV.escape("\tcmd") == "'\tcmd"
    assert CSV.escape("\rcmd") == "\"'\rcmd\""
  end

  test "quotes separators and leaves plain values alone" do
    assert CSV.escape("order.created") == "order.created"
    assert CSV.escape("a,b") == "\"a,b\""
    assert CSV.escape(nil) == ""
    assert CSV.escape(42) == "42"
  end
end
