defmodule Jobcelis.WebhookVerifier do
  @moduledoc """
  Verify webhook signatures using HMAC-SHA256.
  """

  @doc """
  Verify that a webhook request body matches the provided HMAC-SHA256 signature.

  ## Examples

      iex> Jobcelis.WebhookVerifier.verify("secret", ~s({"topic":"order.created"}), signature)
      true
  """
  @spec verify(String.t(), String.t(), String.t()) :: boolean()
  def verify(secret, body, signature) when is_binary(secret) and is_binary(body) and is_binary(signature) do
    expected = :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)
    Plug.Crypto.secure_compare(expected, signature)
  end

  def verify(_secret, _body, _signature), do: false
end
