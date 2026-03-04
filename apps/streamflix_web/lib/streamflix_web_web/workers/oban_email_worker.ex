defmodule StreamflixWebWeb.Workers.ObanEmailWorker do
  @moduledoc """
  Sends emails asynchronously via Oban to avoid blocking HTTP requests.
  Supports email_confirmation and reset_password types.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  @impl true
  def perform(%Oban.Job{
        args: %{
          "type" => "email_confirmation",
          "email" => email,
          "url" => url,
          "locale" => locale
        }
      }) do
    user = %{email: email}
    StreamflixWebWeb.Mailer.send_email_confirmation(user, url, locale)
    :ok
  end

  def perform(%Oban.Job{
        args: %{"type" => "reset_password", "email" => email, "url" => url, "locale" => locale}
      }) do
    user = %{email: email}
    StreamflixWebWeb.Mailer.send_reset_password_email(user, url, locale)
    :ok
  end

  def perform(%Oban.Job{args: args}) do
    Logger.warning("[ObanEmailWorker] Unknown email type: #{inspect(args)}")
    :ok
  end
end
