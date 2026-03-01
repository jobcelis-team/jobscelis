defmodule StreamflixWebWeb.Plugs.Compress do
  @moduledoc """
  Compresses response bodies using gzip when the client supports it.
  Reduces JSON API responses by ~70% and HTML by ~80%.
  """
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    Plug.Conn.register_before_send(conn, fn conn ->
      if compressible?(conn) do
        body = compress_body(conn)

        if body do
          conn
          |> Plug.Conn.put_resp_header("content-encoding", "gzip")
          |> Plug.Conn.put_resp_header("vary", "Accept-Encoding")
          |> Map.put(:resp_body, body)
        else
          conn
        end
      else
        conn
      end
    end)
  end

  defp compressible?(conn) do
    accepts_gzip?(conn) and not already_encoded?(conn) and has_body?(conn)
  end

  defp accepts_gzip?(conn) do
    case Plug.Conn.get_req_header(conn, "accept-encoding") do
      [encoding | _] -> String.contains?(encoding, "gzip")
      _ -> false
    end
  end

  defp already_encoded?(conn) do
    Plug.Conn.get_resp_header(conn, "content-encoding") != []
  end

  defp has_body?(conn) do
    conn.resp_body != nil and conn.resp_body != "" and IO.iodata_length(conn.resp_body) > 256
  end

  defp compress_body(conn) do
    try do
      :zlib.gzip(conn.resp_body)
    rescue
      _ -> nil
    end
  end
end
