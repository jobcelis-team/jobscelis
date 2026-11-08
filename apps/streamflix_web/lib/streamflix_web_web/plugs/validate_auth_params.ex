defmodule StreamflixWebWeb.Plugs.ValidateAuthParams do
  @moduledoc """
  Validates and sanitizes login/signup params: length, email format.
  Rejects oversized payloads and dangerous characters before reaching the service.
  """
  import Plug.Conn

  @max_email_len 254
  @min_password_len 8
  @max_password_len 72
  @max_name_len 255
  @email_regex ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  def init(opts), do: opts

  def call(conn, _opts) do
    # path_info (not request_path): "/auth/refresh/" routes to the same action
    case Enum.take(conn.path_info, -2) do
      ["auth", "refresh"] -> conn
      ["mfa", "verify"] -> conn
      _ -> validate(conn)
    end
  end

  defp validate(conn) do
    params = conn.params || %{}

    # Only plain strings are accepted: JSON objects or arrays (maps/lists after
    # parsing) are rejected with a 400 instead of crashing on to_string/1.
    email = params["email"]
    password = params["password"]
    raw_name = params["name"]

    cond do
      not (is_binary(email) and is_binary(password)) ->
        reject(conn, "Email and password are required")

      not (is_nil(raw_name) or is_binary(raw_name)) ->
        reject(conn, "Invalid name")

      true ->
        validate_strings(conn, params, email, password, raw_name)
    end
  end

  defp validate_strings(conn, params, email, password, raw_name) do
    email = String.trim(email) |> String.downcase()
    name = raw_name && raw_name |> String.trim() |> String.slice(0, @max_name_len)

    cond do
      byte_size(email) > @max_email_len ->
        reject(conn, "Email is too long")

      byte_size(password) < @min_password_len ->
        reject(conn, "Password must be at least #{@min_password_len} characters")

      byte_size(password) > @max_password_len ->
        reject(conn, "Password is too long")

      not email_valid?(email) ->
        reject(conn, "Invalid email")

      true ->
        safe = %{}
        safe = Map.put(safe, "email", email)
        safe = Map.put(safe, "password", password)
        safe = if name, do: Map.put(safe, "name", name), else: safe
        safe = if params["plan"], do: Map.put(safe, "plan", params["plan"]), else: safe

        safe =
          if params["remember"], do: Map.put(safe, "remember", params["remember"]), else: safe

        %{conn | params: safe, body_params: safe}
    end
  end

  defp email_valid?(email) do
    String.length(email) >= 3 and String.match?(email, @email_regex)
  end

  # API-only plug: messages in English, like the rest of the API errors
  defp reject(conn, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, Jason.encode!(%{error: message}))
    |> halt()
  end
end
