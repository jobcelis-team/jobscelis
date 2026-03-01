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
        {:ok, token, _claims} = StreamflixAccounts.generate_token(user)
        api_key = Keyword.get(opts, :api_key)

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
        {:ok, token, _claims} = StreamflixAccounts.generate_token(user)

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
  """
  def login(conn, %{"email" => email, "password" => password}) do
    case StreamflixAccounts.authenticate(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = StreamflixAccounts.generate_token(user)

        # Update last login
        StreamflixAccounts.update_user(user, %{last_login_at: DateTime.utc_now()})

        conn
        |> put_status(:ok)
        |> json(%{
          user: %{
            id: user.id,
            email: user.email,
            name: user.name
          },
          token: token
        })

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
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
