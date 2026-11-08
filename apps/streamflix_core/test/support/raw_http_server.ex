defmodule StreamflixCore.RawHttpServer do
  @moduledoc """
  Minimal one-shot HTTP server for tests of outbound requests.

  `start(responder)` listens on 127.0.0.1 and returns `{port, ref}`. For each
  accepted connection it reads the request head, sends `{:raw_http_request, ref,
  head}` to the test process and calls `responder.(socket)` to write the
  response (which may be slow, huge, compressed, ...).
  """

  def start(responder) do
    test_pid = self()
    ref = make_ref()

    {:ok, listen} =
      :gen_tcp.listen(0, [
        :binary,
        packet: :raw,
        active: false,
        reuseaddr: true,
        ip: {127, 0, 0, 1}
      ])

    {:ok, port} = :inet.port(listen)

    spawn_link(fn -> accept_loop(listen, test_pid, ref, responder) end)

    {port, ref}
  end

  defp accept_loop(listen, test_pid, ref, responder) do
    case :gen_tcp.accept(listen) do
      {:ok, socket} ->
        head = read_head(socket, "")
        send(test_pid, {:raw_http_request, ref, head})

        try do
          responder.(socket)
        catch
          _, _ -> :ok
        end

        :gen_tcp.close(socket)
        accept_loop(listen, test_pid, ref, responder)

      _ ->
        :ok
    end
  end

  defp read_head(socket, acc) do
    if String.contains?(acc, "\r\n\r\n") do
      acc
    else
      case :gen_tcp.recv(socket, 0, 5_000) do
        {:ok, data} -> read_head(socket, acc <> data)
        _ -> acc
      end
    end
  end
end
