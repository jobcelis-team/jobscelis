# Known false positives. Re-check when upgrading Erlang/OTP or Ecto.
[
  # OTP 28+ flags Ecto.Multi.new() |> Ecto.Multi.insert(...) because
  # Ecto.Multi holds an opaque MapSet; the call is correct.
  {"lib/streamflix_core/gdpr.ex", :call_without_opaque}
]
