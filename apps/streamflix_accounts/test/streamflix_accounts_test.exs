defmodule StreamflixAccountsTest do
  use ExUnit.Case

  test "guardian is configured" do
    assert is_binary(StreamflixAccounts.Guardian.config(:issuer))
  end
end
