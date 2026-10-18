defmodule StreamflixCore.Platform.DeliveryWorkerTest do
  use ExUnit.Case, async: true

  alias StreamflixCore.Platform.DeliveryWorker

  describe "describe_error/1" do
    test "transport errors become readable messages" do
      assert DeliveryWorker.describe_error(%Req.TransportError{reason: :timeout}) ==
               "Connection error: timeout (no response from the endpoint)"

      assert DeliveryWorker.describe_error(%Req.TransportError{reason: :econnrefused}) ==
               "Connection error: connection refused"
    end

    test "unknown transport reasons use the exception message" do
      error = %Req.TransportError{reason: :ehostdown}

      assert DeliveryWorker.describe_error(error) ==
               "Connection error: " <> Exception.message(error)
    end

    test "strings pass through and other terms are inspected" do
      assert DeliveryWorker.describe_error("missing webhook") == "missing webhook"
      assert DeliveryWorker.describe_error({:bad, 1}) == "{:bad, 1}"
    end
  end
end
