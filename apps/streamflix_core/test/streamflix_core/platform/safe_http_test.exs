defmodule StreamflixCore.Platform.SafeHttpTest do
  use ExUnit.Case, async: false

  alias StreamflixCore.Platform.{SafeHttp, UrlGuard}
  alias StreamflixCore.RawHttpServer

  defp pinned(port, host \\ "hooks.example.test") do
    %{scheme: :http, host: host, port: port, ip: {127, 0, 0, 1}, request_target: "/hook?x=1"}
  end

  describe "connect_args/2 (pinned destination)" do
    test "connects to the checked IP and keeps the hostname for Host/SNI/cert checks" do
      p = %{
        scheme: :https,
        host: "hooks.example.com",
        port: 443,
        ip: {93, 184, 216, 34},
        request_target: "/"
      }

      assert {:https, {93, 184, 216, 34}, 443, opts} = SafeHttp.connect_args(p)
      assert opts[:hostname] == "hooks.example.com"
      assert opts[:mode] == :passive
      assert opts[:protocols] == [:http1]
      assert opts[:transport_opts][:timeout] == 5_000
      refute opts[:transport_opts][:inet6]
    end

    test "IPv6 destinations connect over inet6 only" do
      p = %{
        scheme: :https,
        host: "v6.example.com",
        port: 8443,
        ip: {0x2606, 0x4700, 0, 0, 0, 0, 0, 0x1111},
        request_target: "/"
      }

      assert {:https, {0x2606, _, _, _, _, _, _, _}, 8443, opts} =
               SafeHttp.connect_args(p, connect_timeout: 1_000)

      assert opts[:transport_opts][:inet6] == true
      assert opts[:transport_opts][:inet4] == false
      assert opts[:transport_opts][:timeout] == 1_000
    end

    test "request_headers/1 never advertises compression and cannot override Host" do
      headers = SafeHttp.request_headers([{"Accept-Encoding", "gzip"}, {"host", "evil"}])
      assert {"accept-encoding", "identity"} in headers
      refute Enum.any?(headers, fn {k, _} -> String.downcase(k) == "host" end)
      refute {"Accept-Encoding", "gzip"} in headers
    end
  end

  describe "request/2 against a local server" do
    test "sends the original Host header to the pinned address, raw body" do
      {port, ref} =
        RawHttpServer.start(fn socket ->
          :gen_tcp.send(socket, "HTTP/1.1 201 Created\r\ncontent-length: 2\r\n\r\nok")
        end)

      assert {:ok, %{status: 201, body: "ok", truncated: false, ip: "127.0.0.1"}} =
               SafeHttp.request(pinned(port), method: :post, body: "{}")

      assert_receive {:raw_http_request, ^ref, head}
      assert head =~ "POST /hook?x=1 HTTP/1.1"
      assert head =~ ~r/host: hooks\.example\.test:#{port}/i
      assert head =~ ~r/accept-encoding: identity/i
    end

    test "reads at most max_body bytes of a huge response" do
      {port, _ref} =
        RawHttpServer.start(fn socket ->
          :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\ncontent-length: 5000000\r\n\r\n")
          chunk = :binary.copy("a", 100_000)
          for _ <- 1..50, do: :gen_tcp.send(socket, chunk)
        end)

      assert {:ok, %{status: 200, body: body, truncated: true}} =
               SafeHttp.request(pinned(port), method: :get, max_body: 1_000)

      assert byte_size(body) == 1_000
    end

    test "compressed bodies are not decompressed (no decompression bomb)" do
      bomb = :zlib.gzip(:binary.copy("0", 5_000_000))

      {port, _ref} =
        RawHttpServer.start(fn socket ->
          :gen_tcp.send(
            socket,
            "HTTP/1.1 200 OK\r\ncontent-encoding: gzip\r\ncontent-length: #{byte_size(bomb)}\r\n\r\n" <>
              bomb
          )
        end)

      assert {:ok, resp} = SafeHttp.request(pinned(port), method: :get, max_body: 2_000)
      assert byte_size(resp.body) <= 2_000
      assert SafeHttp.printable_body(resp) =~ "gzip-encoded response body not decoded"
    end

    test "a server trickling bytes is cut off by the total deadline" do
      {port, _ref} =
        RawHttpServer.start(fn socket ->
          :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\ncontent-length: 1000\r\n\r\n")

          for _ <- 1..100 do
            Process.sleep(50)
            :gen_tcp.send(socket, "a")
          end
        end)

      started = System.monotonic_time(:millisecond)

      assert {:error, %Req.TransportError{reason: :timeout}} =
               SafeHttp.request(pinned(port), method: :get, receive_timeout: 1_000, deadline: 300)

      assert System.monotonic_time(:millisecond) - started < 1_500
    end

    test "close-delimited bodies are returned" do
      {port, _ref} =
        RawHttpServer.start(fn socket ->
          :gen_tcp.send(socket, "HTTP/1.0 200 OK\r\n\r\nhello")
        end)

      assert {:ok, %{status: 200, body: "hello"}} = SafeHttp.request(pinned(port), method: :get)
    end

    test "printable_body/1 makes binary bodies storable" do
      resp = %{headers: [], body: <<"ok", 0, 255, 254>>, truncated: true}
      text = SafeHttp.printable_body(resp)
      assert String.valid?(text)
      refute text =~ <<0>>
      assert String.ends_with?(text, "...")
    end
  end

  describe "SSRF guard" do
    setup do
      previous = Application.get_env(:streamflix_core, :allow_private_destinations)
      Application.put_env(:streamflix_core, :allow_private_destinations, false)

      on_exit(fn ->
        Application.put_env(:streamflix_core, :allow_private_destinations, previous)
      end)
    end

    test "internal destinations are blocked before connecting" do
      assert {:error, {:blocked, :private_address}} =
               SafeHttp.request("http://127.0.0.1:1/hook", method: :post)

      assert {:error, {:blocked, :private_address}} =
               SafeHttp.request("http://[64:ff9b::a9fe:a9fe]/", method: :get)
    end

    test "the pinned IP is the one that was checked (no second resolution)" do
      # A rebinding resolver answers a public IP first, an internal one afterwards
      counter = :counters.new(1, [])

      resolver = fn _host ->
        :counters.add(counter, 1, 1)
        if :counters.get(counter, 1) == 1, do: [{93, 184, 216, 34}], else: [{127, 0, 0, 1}]
      end

      assert {:ok, %{ip: {93, 184, 216, 34}, host: "rebind.example.com"} = p} =
               UrlGuard.pin("https://rebind.example.com/x", resolver)

      assert {:https, {93, 184, 216, 34}, 443, opts} = SafeHttp.connect_args(p)
      assert opts[:hostname] == "rebind.example.com"
      assert :counters.get(counter, 1) == 1
    end
  end
end
