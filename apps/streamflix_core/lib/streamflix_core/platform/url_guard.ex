defmodule StreamflixCore.Platform.UrlGuard do
  @moduledoc """
  SSRF protection for user-supplied outbound URLs (webhooks, job "Call URL",
  notification meta-webhooks, webhook tests).

  A destination is allowed only if it is http(s) and every address its host
  resolves to is a public address: loopback, private (RFC 1918), CGNAT,
  link-local (incl. the 169.254.169.254 cloud metadata service), multicast,
  reserved and the IPv6 equivalents are rejected. Checked when the URL is saved
  and again right before each request (DNS can change). Outbound requests must
  also disable redirects (`redirect: false`) so a public host cannot bounce the
  request to an internal one.

  Development and test can allow private destinations (local sandbox, local
  receivers) with `config :streamflix_core, allow_private_destinations: true`.
  """

  @type reason :: :invalid_url | :unsupported_scheme | :unresolvable_host | :private_address

  @doc "Request options that must be used for every outbound user-supplied URL."
  def req_options, do: [redirect: false]

  @doc "Returns :ok or {:error, reason} for an outbound destination URL."
  @spec check(String.t() | nil) :: :ok | {:error, reason}
  def check(url) when is_binary(url) do
    with {:ok, host} <- parse(url) do
      if allow_private?(), do: :ok, else: check_host(host)
    end
  end

  def check(_), do: {:error, :invalid_url}

  @doc "Human readable message for a rejection reason."
  def message(:invalid_url), do: "is not a valid URL"
  def message(:unsupported_scheme), do: "must use http or https"
  def message(:unresolvable_host), do: "host could not be resolved"

  def message(:private_address),
    do: "must point to a public address (private and internal networks are not allowed)"

  @doc "Ecto changeset validation for a URL field."
  def validate_changeset(%Ecto.Changeset{} = changeset, field) do
    Ecto.Changeset.validate_change(changeset, field, fn ^field, url ->
      case check(url) do
        :ok -> []
        {:error, reason} -> [{field, message(reason)}]
      end
    end)
  end

  defp parse(url) do
    case URI.parse(String.trim(url)) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        {:ok, host |> String.trim_leading("[") |> String.trim_trailing("]") |> String.downcase()}

      %URI{scheme: scheme} when scheme not in [nil, "http", "https"] ->
        {:error, :unsupported_scheme}

      _ ->
        {:error, :invalid_url}
    end
  end

  defp check_host(host) do
    case resolve(host) do
      [] -> {:error, :unresolvable_host}
      addrs -> if Enum.all?(addrs, &public?/1), do: :ok, else: {:error, :private_address}
    end
  end

  defp resolve(host) do
    charlist = String.to_charlist(host)

    case :inet.parse_address(charlist) do
      {:ok, ip} ->
        [ip]

      {:error, _} ->
        v4 = getaddrs(charlist, :inet)
        v6 = getaddrs(charlist, :inet6)
        Enum.uniq(v4 ++ v6)
    end
  end

  defp getaddrs(host, family) do
    case :inet.getaddrs(host, family) do
      {:ok, addrs} -> addrs
      _ -> []
    end
  end

  @doc false
  # IPv4
  def public?({a, b, _, _} = ip) when tuple_size(ip) == 4 do
    not (a == 0 or a == 10 or a == 127 or a >= 224 or
           (a == 100 and b in 64..127) or
           (a == 169 and b == 254) or
           (a == 172 and b in 16..31) or
           (a == 192 and b == 168) or
           (a == 192 and b == 0) or
           (a == 198 and b in 18..19))
  end

  # IPv4-mapped / -compatible IPv6 (::ffff:a.b.c.d)
  def public?({0, 0, 0, 0, 0, 0xFFFF, hi, lo}), do: public?(ipv4_from(hi, lo))

  def public?({0, 0, 0, 0, 0, 0, hi, lo}) when {hi, lo} != {0, 0} and {hi, lo} != {0, 1},
    do: public?(ipv4_from(hi, lo))

  # IPv6: unspecified, loopback, unique-local fc00::/7, link-local fe80::/10,
  # multicast ff00::/8, documentation 2001:db8::/32
  def public?({0, 0, 0, 0, 0, 0, 0, 0}), do: false
  def public?({0, 0, 0, 0, 0, 0, 0, 1}), do: false

  def public?({first, second, _, _, _, _, _, _}) do
    not (Bitwise.band(first, 0xFE00) == 0xFC00 or
           Bitwise.band(first, 0xFFC0) == 0xFE80 or
           Bitwise.band(first, 0xFF00) == 0xFF00 or
           (first == 0x2001 and second == 0x0DB8))
  end

  def public?(_), do: false

  defp ipv4_from(hi, lo),
    do: {Bitwise.bsr(hi, 8), Bitwise.band(hi, 0xFF), Bitwise.bsr(lo, 8), Bitwise.band(lo, 0xFF)}

  defp allow_private?,
    do: Application.get_env(:streamflix_core, :allow_private_destinations, false)
end
