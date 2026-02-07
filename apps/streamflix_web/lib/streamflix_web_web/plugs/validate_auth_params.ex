defmodule StreamflixWebWeb.Plugs.ValidateAuthParams do
  @moduledoc """
  Valida y sanitiza parámetros de login/registro: longitud, formato de email.
  Evita payloads enormes y caracteres peligrosos antes de llegar al servicio.
  """
  import Plug.Conn

  @max_email_len 254
  @min_password_len 8
  @max_password_len 72
  @max_name_len 255
  @email_regex ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  def init(opts), do: opts

  def call(conn, _opts) do
    if String.ends_with?(conn.request_path, "/auth/refresh") do
      conn
    else
      validate(conn)
    end
  end

  defp validate(conn) do
    params = conn.params || %{}

    email = params["email"] && to_string(params["email"])
    password = params["password"] && to_string(params["password"])

    if is_binary(email) and is_binary(password) do
      email = String.trim(email) |> String.downcase()
      name = params["name"] && (params["name"] |> to_string() |> String.trim() |> String.slice(0, @max_name_len))

      cond do
        byte_size(email) > @max_email_len ->
          reject(conn, "Email demasiado largo")

        byte_size(password) < @min_password_len ->
          reject(conn, "La contraseña debe tener al menos #{@min_password_len} caracteres")

        byte_size(password) > @max_password_len ->
          reject(conn, "Contraseña demasiado larga")

        not email_valid?(email) ->
          reject(conn, "Email no válido")

        true ->
          safe = %{}
          safe = Map.put(safe, "email", email)
          safe = Map.put(safe, "password", password)
          safe = if name, do: Map.put(safe, "name", name), else: safe
          safe = if params["plan"], do: Map.put(safe, "plan", params["plan"]), else: safe
          safe = if params["remember"], do: Map.put(safe, "remember", params["remember"]), else: safe

          %{conn | params: safe, body_params: safe}
      end
    else
      reject(conn, "Faltan email o contraseña")
    end
  end

  defp email_valid?(email) do
    String.length(email) >= 3 and String.match?(email, @email_regex)
  end

  defp reject(conn, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, Jason.encode!(%{error: message}))
    |> halt()
  end
end
