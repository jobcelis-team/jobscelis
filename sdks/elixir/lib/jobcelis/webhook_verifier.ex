defmodule Jobcelis.WebhookVerifier do
  @moduledoc """
  Verify webhook signatures using HMAC-SHA256.

  The Jobcelis backend signs webhook payloads with HMAC-SHA256, Base64-encoded
  without padding, and sends the signature in the `x-signature` header with
  the format `sha256=<base64_no_padding>`.
  """

  @doc """
  Verify that a webhook request body matches the provided HMAC-SHA256 signature.

  The `signature` parameter is the full header value, e.g. `"sha256=abc123..."`.

  ## Examples

      iex> Jobcelis.WebhookVerifier.verify("secret", ~s({"topic":"order.created"}), "sha256=" <> sig)
      true
  """
  @spec verify(String.t(), String.t(), String.t()) :: boolean()
  def verify(secret, body, "sha256=" <> received_sig)
      when is_binary(secret) and is_binary(body) do
    expected_sig =
      :crypto.mac(:hmac, :sha256, secret, body)
      |> Base.encode64(padding: false)

    Plug.Crypto.secure_compare(expected_sig, received_sig)
  end

  def verify(_secret, _body, _signature), do: false
end
