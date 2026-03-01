defmodule StreamflixWebWeb.ApiSpec do
  alias OpenApiSpex.{Info, OpenApi, Paths, Server, Components, SecurityScheme}
  alias StreamflixWebWeb.Router

  @behaviour OpenApi

  @impl OpenApi
  def spec() do
    %OpenApi{
      info: %Info{
        title: "Jobcelis API",
        version: "1.0.0",
        description: "API de eventos, webhooks y jobs. Envía JSON, nosotros enrutamos y entregamos."
      },
      servers: [
        %Server{url: "/", description: "Current server"}
      ],
      paths: Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{
          "api_key" => %SecurityScheme{
            type: "apiKey",
            name: "X-Api-Key",
            in: "header",
            description: "API Key del proyecto. También acepta Authorization: Bearer <token>"
          },
          "bearer" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT",
            description: "JWT token obtenido de /api/v1/auth/login"
          }
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
