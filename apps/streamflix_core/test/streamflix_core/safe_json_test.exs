defmodule StreamflixCore.SafeJsonTest do
  use ExUnit.Case, async: true

  alias StreamflixCore.SafeJson

  defp nested(n), do: String.duplicate("[", n) <> String.duplicate("]", n)

  test "accepts payloads up to the nesting limit" do
    assert {:ok, _} = SafeJson.decode(nested(SafeJson.max_depth()))
    assert {:ok, %{"a" => %{"b" => [1, 2]}}} = SafeJson.decode(~s({"a":{"b":[1,2]}}))
  end

  test "rejects payloads nested past the limit" do
    assert {:error, :too_deep} = SafeJson.decode(nested(SafeJson.max_depth() + 1))
    assert {:error, :too_deep} = SafeJson.decode(nested(100_000))
    assert_raise ArgumentError, fn -> SafeJson.decode!(nested(100_000)) end
  end

  test "invalid JSON is still a decode error" do
    assert {:error, %Jason.DecodeError{}} = SafeJson.decode("{")
  end
end
