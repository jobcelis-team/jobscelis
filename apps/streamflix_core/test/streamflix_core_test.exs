defmodule StreamflixCoreTest do
  use ExUnit.Case

  test "repo is configured" do
    assert StreamflixCore.Repo.config()[:database] != nil
  end
end
