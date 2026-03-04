defmodule StreamflixWebWeb.Api.V1.AuthController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixAccounts
  alias StreamflixWebWeb.Schemas

  action_fallback StreamflixWebWeb.FallbackController

  tags(["Authentication"])
  security([])

  operation(:register,
    summary: "Register a new user account",
    request_body:
      {"Registration attributes", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         required: [:email, :password],
         properties: %{
           email: %OpenApiSpex.Schema{type: :string, format: :email},
           password: %OpenApiSpex.Schema{type: :string},
           name: %OpenApiSpex.Schema{type: :string}
         }
       }},
    responses: [
      created:
        {"User registered", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             user: %OpenApiSpex.Schema{type: :object},
             token: %OpenApiSpex.Schema{type: :string},
             api_key: %OpenApiSpex.Schema{type: :string, nullable: true}
           }
         }},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ErrorResponse}
    ]
  )

  @doc """
  Registers a new user.
  """
  def register(conn, %{"email" => email, "password" => password} = params) do
    attrs = %{
      email: email,
      password: password,
      name: params["name"]
    }

    case StreamflixAccounts.register_user(attrs) do
      {:ok, user, opts} ->
        {:ok, token, claims} = StreamflixAccounts.generate_token(user)
        api_key = Keyword.get(opts, :api_key)
        audit_opts = conn_audit_opts(conn, "api")
        StreamflixAccounts.create_session(user.id, claims["jti"], audit_opts)

        conn
        |> put_status(:created)
        |> json(%{
          user: %{
            id: user.id,
            email: user.email,
            name: user.name
          },
          token: token,
          api_key: api_key
        })

      {:ok, user} ->
        {:ok, token, claims} = StreamflixAccounts.generate_token(user)
        audit_opts = conn_audit_opts(conn, "api")
        StreamflixAccounts.create_session(user.id, claims["jti"], audit_opts)

        conn
        |> put_status(:created)
        |> json(%{
          user: %{
            id: user.id,
            email: user.email,
            name: user.name
          },
          token: token
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  operation(:login,
    summary: "Authenticate and get token",
    request_body:
      {"Login credentials", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         required: [:email, :password],
         properties: %{
           email: %OpenApiSpex.Schema{type: :string, format: :email},
           password: %OpenApiSpex.Schema{type: :string}
         }
       }},
    responses: [
      ok:
        {"Login successful", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             user: %OpenApiSpex.Schema{type: :object},
             token: %OpenApiSpex.Schema{type: :string}
           }
         }},
      unauthorized: {"Invalid credentials", "application/json", Schemas.ErrorResponse}
    ]
  )

  @doc """
  Authenticates a user and returns a token.
  If MFA is enabled, returns mfa_required: true with a short-lived MFA challenge token.
  """
  def login(conn, %{"email" => email, "password" => password}) do
    opts = conn_audit_opts(conn, "api")

    case StreamflixAccounts.authenticate(email, password, opts) do
      {:ok, user} ->
        if user.mfa_enabled do
          # Generate a short-lived MFA challenge token (5 min TTL)
          {:ok, mfa_token, _claims} =
            StreamflixAccounts.Guardian.encode_and_sign(
              user,
              %{"type" => "mfa_challenge"},
              ttl: {5, :minute}
            )

          conn
          |> put_status(:ok)
          |> json(%{
            mfa_required: true,
            mfa_token: mfa_token
          })
        else
          {:ok, token, claims} = StreamflixAccounts.generate_token(user)
          StreamflixAccounts.create_session(user.id, claims["jti"], opts)
          StreamflixAccounts.update_user(user, %{last_login_at: DateTime.utc_now()})

          conn
          |> put_status(:ok)
          |> json(%{
            user: %{id: user.id, email: user.email, name: user.name},
            token: token
          })
        end

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})

      {:error, :account_locked} ->
        conn
        |> put_status(423)
        |> json(%{
          error:
            "Account temporarily locked due to multiple failed login attempts. Try again in 15 minutes."
        })

      {:error, :account_inactive} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Account is inactive"})
    end
  end

  @doc """
  Verify MFA code for API login. Accepts mfa_token + code.
  """
  def verify_mfa(conn, %{"mfa_token" => mfa_token, "code" => code}) do
    case StreamflixAccounts.Guardian.decode_and_verify(mfa_token) do
      {:ok, %{"type" => "mfa_challenge"} = claims} ->
        case StreamflixAccounts.Guardian.resource_from_claims(claims) do
          {:ok, user} ->
            if StreamflixAccounts.verify_mfa_code(user, String.trim(code)) do
              StreamflixCore.Audit.record("user.mfa_verified",
                user_id: user.id,
                resource_type: "user",
                resource_id: user.id,
                metadata: %{method: "totp_api"}
              )

              {:ok, token, claims} = StreamflixAccounts.generate_token(user)
              audit_opts = conn_audit_opts(conn, "api")
              StreamflixAccounts.create_session(user.id, claims["jti"], audit_opts)
              StreamflixAccounts.update_user(user, %{last_login_at: DateTime.utc_now()})

              conn
              |> put_status(:ok)
              |> json(%{
                user: %{id: user.id, email: user.email, name: user.name},
                token: token
              })
            else
              StreamflixCore.Audit.record("user.mfa_failed",
                user_id: user.id,
                resource_type: "user",
                resource_id: user.id,
                metadata: %{method: "totp_api"}
              )

              conn
              |> put_status(:unauthorized)
              |> json(%{error: "Invalid MFA code"})
            end

          _ ->
            conn |> put_status(:unauthorized) |> json(%{error: "Invalid MFA token"})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Invalid or expired MFA token"})
    end
  end

  def verify_mfa(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "mfa_token and code are required"})
  end

  defp conn_audit_opts(conn, method) do
    ip = StreamflixWebWeb.Plugs.ClientIp.get_client_ip(conn)

    user_agent =
      case Plug.Conn.get_req_header(conn, "user-agent") do
        [ua | _] -> ua
        _ -> nil
      end

    [ip_address: ip, user_agent: user_agent, method: method]
  end

  operation(:refresh,
    summary: "Refresh an authentication token",
    request_body:
      {"Token to refresh", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         required: [:token],
         properties: %{token: %OpenApiSpex.Schema{type: :string}}
       }},
    responses: [
      ok:
        {"Token refreshed", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{token: %OpenApiSpex.Schema{type: :string}}
         }},
      unauthorized: {"Invalid or expired token", "application/json", Schemas.ErrorResponse}
    ]
  )

  @doc """
  Refreshes an authentication token.
  """
  def refresh(conn, %{"token" => token}) do
    case StreamflixAccounts.Services.Authentication.refresh_token(token) do
      {:ok, new_token, _claims} ->
        conn
        |> put_status(:ok)
        |> json(%{token: new_token})

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid or expired token"})
    end
  end
end
