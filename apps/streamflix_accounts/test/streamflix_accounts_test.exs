defmodule StreamflixAccountsTest do
  use ExUnit.Case

  test "guardian is configured" do
    assert StreamflixAccounts.Guardian.config(:issuer) == "streamflix"
  end
end
