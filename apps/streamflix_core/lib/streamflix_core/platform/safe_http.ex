defmodule StreamflixCore.Platform.SafeHttp do
  @moduledoc """
  HTTP client for user-supplied destinations (webhook deliveries, webhook tests,
  "Call URL" jobs, alert channels).

  Hardened against SSRF and resource exhaustion:

    * DNS rebinding: the host is resolved and validated once by
      `StreamflixCore.Platform.UrlGuard.pin/1` and the socket connects to that
      exact address. The original hostname is still used for the `Host` header,
      TLS SNI and certificate verification (Mint's `:hostname` option), so the
      client never performs a second DNS lookup an attacker could answer
      differently.
    * Redirects are never followed.
    * No decompression or decoding: `accept-encoding: identity` is sent and the
      body is kept as raw bytes.
    * Bounded memory: at most `:max_body` bytes of the response body are read,
      then the connection is closed (`truncated: true`). Response headers are
      capped by Mint's `:max_header_list_size`.
    * Bounded time: a connect timeout, a per-read timeout and a total deadline
      for the whole exchange, so a slow server cannot hold a worker forever.

  Each request uses its own connection (no pool), which is closed afterwards.
  """

  alias StreamflixCore.Platform.UrlGuard

  @default_connect_timeout 5_000
  @default_receive_timeout 15_000
  @default_deadline 20_000
  @default_max_body 10_000
  @max_header_list_size 64 * 1024
  @send_timeout 10_000

  @type response :: %{
          status: non_neg_integer(),
          headers: [{String.t(), String.t()}],
          body: binary(),
          truncated: boolean(),
          ip: String.t()
        }

  @type error ::
          {:blocked, UrlGuard.reason()}
          | %Req.TransportError{}
          | Exception.t()

  @doc """
  Sends a request to a user-supplied `url` (or to an already pinned destination).

  Options:
    * `:method` - `:get | :post | :put | :patch | :delete` (default `:post`)
    * `:headers` - list of `{name, value}`
    * `:body` - iodata request body (default empty)
    * `:connect_timeout`, `:receive_timeout` (per read), `:deadline` (total, ms)
    * `:max_body` - max response body bytes kept (default #{@default_max_body})
  """
  @spec request(String.t() | UrlGuard.pinned(), keyword()) ::
          {:ok, response} | {:error, error}
  def request(url, opts \\ [])

  def request(url, opts) when is_binary(url) do
    case UrlGuard.pin(url) do
      {:ok, pinned} -> request(pinned, opts)
      {:error, reason} -> {:error, {:blocked, reason}}
    end
  end

  def request(%{ip: _, host: _} = pinned, opts) do
    deadline =
      System.monotonic_time(:millisecond) + Keyword.get(opts, :deadline, @default_deadline)

    {scheme, address, port, conn_opts} = connect_args(pinned, opts)

    case Mint.HTTP.connect(scheme, address, port, conn_opts) do
      {:ok, conn} ->
        try do
          send_and_receive(conn, pinned, opts, deadline)
        after
          Mint.HTTP.close(conn)
        end

      {:error, error} ->
        {:error, wrap_error(error)}
    end
  end

  @doc """
  Arguments for `Mint.HTTP.connect/4` for a pinned destination: connects to the
  validated IP while the hostname drives `Host`, SNI and certificate checks.
  """
  @spec connect_args(UrlGuard.pinned(), keyword()) ::
          {:http | :https, :inet.ip_address(), :inet.port_number(), keyword()}
  def connect_args(%{scheme: scheme, host: host, port: port, ip: ip}, opts \\ []) do
    # send_timeout: a server that stops reading the request body cannot block
    # the sending process indefinitely.
    transport_opts =
      [
        timeout: Keyword.get(opts, :connect_timeout, @default_connect_timeout),
        send_timeout: @send_timeout
      ] ++
        if tuple_size(ip) == 8, do: [inet6: true, inet4: false], else: []

    {scheme, ip, port,
     [
       hostname: host,
       mode: :passive,
       protocols: [:http1],
       max_header_list_size: @max_header_list_size,
       transport_opts: transport_opts
     ]}
  end

  @doc "Request headers actually sent: caller headers plus identity encoding and a UA."
  @spec request_headers([{String.t(), String.t()}]) :: [{String.t(), String.t()}]
  def request_headers(headers) do
    headers =
      Enum.reject(headers, fn {k, _} -> String.downcase(k) in ["accept-encoding", "host"] end)

    headers = [{"accept-encoding", "identity"} | headers]

    if Enum.any?(headers, fn {k, _} -> String.downcase(k) == "user-agent" end),
      do: headers,
      else: headers ++ [{"user-agent", "Jobcelis-Webhooks/1.0"}]
  end

  defp send_and_receive(conn, pinned, opts, deadline) do
    method = opts |> Keyword.get(:method, :post) |> to_string() |> String.upcase()
    headers = request_headers(Keyword.get(opts, :headers, []))
    body = Keyword.get(opts, :body, "")

    state = %{
      status: nil,
      headers: [],
      body: [],
      size: 0,
      max_body: Keyword.get(opts, :max_body, @default_max_body),
      receive_timeout: Keyword.get(opts, :receive_timeout, @default_receive_timeout),
      deadline: deadline,
      ip: pinned.ip |> :inet.ntoa() |> to_string()
    }

    case Mint.HTTP.request(conn, method, pinned.request_target, headers, body) do
      {:ok, conn, ref} -> receive_loop(conn, ref, state)
      {:error, _conn, error} -> {:error, wrap_error(error)}
    end
  end

  defp receive_loop(conn, ref, state) do
    remaining = state.deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      {:error, %Req.TransportError{reason: :timeout}}
    else
      case Mint.HTTP.recv(conn, 0, min(remaining, state.receive_timeout)) do
        {:ok, conn, responses} ->
          case handle_responses(responses, ref, state) do
            {:done, state} -> {:ok, finish(state, false)}
            {:truncated, state} -> {:ok, finish(state, true)}
            {:cont, state} -> receive_loop(conn, ref, state)
            {:error, error} -> {:error, error}
          end

        # A close-delimited body ends with the connection closing: Mint still
        # hands over the final responses (including :done) with the error.
        {:error, _conn, error, responses} ->
          case handle_responses(responses, ref, state) do
            {:done, state} -> {:ok, finish(state, false)}
            {:truncated, state} -> {:ok, finish(state, true)}
            _ -> {:error, wrap_error(error)}
          end
      end
    end
  end

  defp handle_responses([], _ref, state), do: {:cont, state}

  defp handle_responses([response | rest], ref, state) do
    case response do
      {:status, ^ref, status} ->
        handle_responses(rest, ref, %{state | status: status})

      {:headers, ^ref, headers} ->
        handle_responses(rest, ref, %{state | headers: state.headers ++ headers})

      {:data, ^ref, data} ->
        room = state.max_body - state.size

        if byte_size(data) > room do
          kept = binary_part(data, 0, max(room, 0))
          {:truncated, %{state | body: [state.body, kept], size: state.max_body}}
        else
          handle_responses(rest, ref, %{
            state
            | body: [state.body, data],
              size: state.size + byte_size(data)
          })
        end

      {:done, ^ref} ->
        {:done, state}

      {:error, ^ref, error} ->
        {:error, wrap_error(error)}

      _other ->
        handle_responses(rest, ref, state)
    end
  end

  defp finish(state, truncated) do
    %{
      status: state.status,
      headers: state.headers,
      body: IO.iodata_to_binary(state.body),
      truncated: truncated,
      ip: state.ip
    }
  end

  defp wrap_error(%Mint.TransportError{reason: reason}), do: %Req.TransportError{reason: reason}
  defp wrap_error(%{__exception__: true} = error), do: error
  defp wrap_error(other), do: %Req.TransportError{reason: other}

  @doc """
  Makes a (possibly truncated, possibly binary) response body safe to store in a
  text column and show in the dashboard: compressed bodies are not decoded, invalid
  UTF-8 is replaced and NUL bytes are dropped.
  """
  @spec printable_body(response) :: String.t()
  def printable_body(%{headers: headers, body: body} = resp) do
    encoding =
      Enum.find_value(headers, fn {k, v} -> if String.downcase(k) == "content-encoding", do: v end)

    text =
      if encoding in [nil, "", "identity"] do
        body |> String.replace_invalid("\uFFFD") |> String.replace(<<0>>, "")
      else
        "[#{encoding}-encoded response body not decoded, #{byte_size(body)} bytes]"
      end

    if Map.get(resp, :truncated, false), do: text <> "...", else: text
  end
end
