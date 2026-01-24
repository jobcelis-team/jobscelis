defmodule StreamflixCoreTest do
  use ExUnit.Case
  doctest StreamflixCore

  test "greets the world" do
    assert StreamflixCore.hello() == :world
  end
end
