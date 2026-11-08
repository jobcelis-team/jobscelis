defmodule StreamflixAccounts.DisposableEmail do
  @moduledoc """
  Detects addresses from disposable (temporary) email providers, which bots use
  to create throwaway accounts. Subdomains of a listed domain also match.
  The list covers the most common providers; extend it when new ones show up.
  """

  @domains MapSet.new(~w(
    10minutemail.com 10minutemail.net 20minutemail.com 33mail.com
    burnermail.io byom.de
    cock.li cuvox.de
    dayrep.com discard.email dispostable.com dropmail.me
    einrot.com emailondeck.com emailfake.com emailtemporanea.com emltmp.com
    fakeinbox.com fakemail.net fextemp.com fleckens.hu
    getairmail.com getnada.com grr.la guerrillamail.biz guerrillamail.com
    guerrillamail.de guerrillamail.info guerrillamail.net guerrillamail.org
    guerrillamailblock.com gustr.com
    harakirimail.com
    inboxbear.com inboxkitten.com
    jetable.org
    mail-temp.com mail.tm mailcatch.com maildrop.cc mailinator.com
    mailinator.net mailnesia.com mailpoof.com mailsac.com mintemail.com
    moakt.com mohmal.com mytemp.email
    nada.email
    owlymail.com
    rhyta.com
    sharklasers.com spam4.me spamgourmet.com superrito.com
    teleworm.us temp-mail.io temp-mail.org tempail.com tempinbox.com
    tempmail.com tempmail.net tempmail.plus tempmailo.com tempr.email
    throwawaymail.com tmail.ws tmpmail.net tmpmail.org trashmail.com
    trashmail.de trashmail.net
    yopmail.com yopmail.fr yopmail.net
  ))

  @doc "True when the address belongs to a known disposable email provider."
  @spec disposable?(String.t() | nil) :: boolean()
  def disposable?(email) when is_binary(email) do
    case String.split(email, "@") do
      [_local, domain] -> domain |> String.downcase() |> String.trim() |> listed?()
      _ -> false
    end
  end

  def disposable?(_), do: false

  # "mail.yopmail.com" matches "yopmail.com"
  defp listed?(domain) do
    parts = String.split(domain, ".")

    Enum.any?(0..max(length(parts) - 2, 0)//1, fn i ->
      parts |> Enum.drop(i) |> Enum.join(".") |> then(&MapSet.member?(@domains, &1))
    end)
  end
end
