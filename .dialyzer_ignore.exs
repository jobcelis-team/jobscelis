# Known false positives. Re-check when upgrading Erlang/OTP or Ecto.
[
  # OTP 28+ flags Ecto.Multi.new() |> Ecto.Multi.insert(...) because
  # Ecto.Multi holds an opaque MapSet; the call is correct.
  {"lib/streamflix_core/gdpr.ex", :call_without_opaque},
  # OTP 29 flags the plural-forms call that `use Gettext.Backend` generates;
  # the generated code is correct.
  {"lib/streamflix_web_web/gettext.ex", :call_without_opaque}
]
