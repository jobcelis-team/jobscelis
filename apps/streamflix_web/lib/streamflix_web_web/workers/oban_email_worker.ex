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
    %{email: email}
    |> StreamflixWebWeb.Mailer.send_email_confirmation(url, locale)
    |> to_job_result()
  end

  def perform(%Oban.Job{
        args: %{"type" => "reset_password", "email" => email, "url" => url, "locale" => locale}
      }) do
    %{email: email}
    |> StreamflixWebWeb.Mailer.send_reset_password_email(url, locale)
    |> to_job_result()
  end

  def perform(%Oban.Job{args: args}) do
    # Never log args: they contain the recipient address and a one-time link
    Logger.warning("Unknown email type", worker: "ObanEmailWorker", error: inspect(args["type"]))
    {:cancel, :unknown_email_type}
  end

  # A failed send used to return :ok, so Oban marked it done and the user never
  # got the email. Provider rejections (4xx) are permanent; everything else retries.
  defp to_job_result(:ok), do: :ok

  defp to_job_result({:error, {:resend_error, status, _body}})
       when status in 400..499 and status != 429,
       do: {:cancel, {:resend_rejected, status}}

  defp to_job_result({:error, reason}), do: {:error, reason}
end
