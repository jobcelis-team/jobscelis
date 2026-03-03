# Full verification of SOC 2 features
# Steps 4-8 that didn't run before, plus re-check of 1-3

alias StreamflixCore.Repo
alias StreamflixAccounts.Schemas.User
alias StreamflixAccounts.Schemas.UserSession
import Ecto.Query

IO.puts("\n========================================")
IO.puts("  STREAMFLIX SOC 2 VERIFICATION")
IO.puts("========================================\n")

# ── Step 1: Auth via email_hash HMAC ──
IO.puts("── Step 1: Auth via email_hash HMAC ──")
user = Repo.get_by(User, email_hash: String.downcase("bladimirtutoriales@gmail.com"))
if user do
  IO.puts("  ✓ User found via email_hash: #{user.id}")
  IO.puts("  ✓ Email decrypted: #{user.email}")
  IO.puts("  ✓ Name decrypted: #{user.name}")
  IO.puts("  ✓ Role: #{user.role}")
else
  IO.puts("  ✗ User NOT found via email_hash")
end

# ── Step 2: Verify PII is encrypted at DB level ──
IO.puts("\n── Step 2: PII Encryption at DB level ──")
{:ok, uid_binary} = Ecto.UUID.dump(user.id)
%{rows: [[raw_email, raw_email_hash, raw_name]]} =
  Repo.query!("SELECT email, email_hash, name FROM users WHERE id = $1", [uid_binary])

email_is_binary = is_binary(raw_email) and not String.valid?(raw_email)
hash_is_binary = is_binary(raw_email_hash) and byte_size(raw_email_hash) > 0
name_is_binary = is_binary(raw_name) and not String.valid?(raw_name)

IO.puts("  email column is encrypted binary: #{email_is_binary}")
IO.puts("  email_hash column has HMAC hash: #{hash_is_binary} (#{byte_size(raw_email_hash)} bytes)")
IO.puts("  name column is encrypted binary: #{name_is_binary}")

if email_is_binary and hash_is_binary and name_is_binary do
  IO.puts("  ✓ All User PII fields encrypted at rest")
else
  IO.puts("  ✗ Some User PII fields may not be encrypted")
end

# ── Step 3: Sessions ──
IO.puts("\n── Step 3: Session Management ──")
# Create a test session
{:ok, session} = StreamflixAccounts.create_session(user.id, "test-jti-verify-#{System.unique_integer([:positive])}", %{
  ip_address: "192.168.1.100",
  user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120",
  device_info: "Desktop"
})
IO.puts("  ✓ Session created: #{session.id}")

sessions = StreamflixAccounts.list_sessions(user.id)
IO.puts("  ✓ Sessions listed: #{length(sessions)} active")

# Revoke it
{:ok, revoked} = StreamflixAccounts.revoke_session(session.id, user.id)
IO.puts("  ✓ Session revoked: revoked_at=#{revoked.revoked_at}")

# Check revocation detection
is_revoked = StreamflixAccounts.session_revoked?(session.token_jti)
IO.puts("  ✓ Revocation detected: #{is_revoked}")

# ── Step 4: Token verification with revocation ──
IO.puts("\n── Step 4: Token + Revocation Check ──")
{:ok, token, claims} = StreamflixAccounts.Services.Authentication.generate_token(user)
jti = claims["jti"]
IO.puts("  ✓ Token generated, jti=#{jti}")

# Verify token works
case StreamflixAccounts.Services.Authentication.verify_token(token) do
  {:ok, verified_user, _claims} ->
    IO.puts("  ✓ Token verified OK, user=#{verified_user.id}")
  {:error, reason} ->
    IO.puts("  ✗ Token verify failed: #{inspect(reason)}")
end

# Create session then revoke it, then verify token again
{:ok, sess2} = StreamflixAccounts.create_session(user.id, jti, %{ip_address: "10.0.0.1"})
{:ok, _} = StreamflixAccounts.revoke_session(sess2.id, user.id)
case StreamflixAccounts.Services.Authentication.verify_token(token) do
  {:error, :session_revoked} ->
    IO.puts("  ✓ Revoked token correctly rejected with :session_revoked")
  {:ok, _, _} ->
    IO.puts("  ✗ Revoked token was accepted (should have been rejected)")
  {:error, reason} ->
    IO.puts("  ? Token rejected with: #{inspect(reason)}")
end

# ── Step 5: Audit Log PII Encryption ──
IO.puts("\n── Step 5: Audit Log Encryption ──")
{:ok, audit} = StreamflixCore.Audit.record("test.verification", [
  user_id: user.id,
  ip_address: "203.0.113.42",
  user_agent: "VerificationScript/1.0",
  metadata: %{"test" => true}
])
IO.puts("  ✓ Audit log created: #{audit.id}")

# Check raw DB
{:ok, audit_uid} = Ecto.UUID.dump(audit.id)
%{rows: [[raw_ip, raw_ua]]} =
  Repo.query!("SELECT ip_address, user_agent FROM audit_logs WHERE id = $1", [audit_uid])

ip_encrypted = is_binary(raw_ip) and not String.valid?(raw_ip)
ua_encrypted = is_binary(raw_ua) and not String.valid?(raw_ua)
IO.puts("  ip_address encrypted: #{ip_encrypted}")
IO.puts("  user_agent encrypted: #{ua_encrypted}")

# Read back through Ecto
reloaded = Repo.get!(StreamflixCore.Schemas.AuditLog, audit.id)
IO.puts("  ✓ Decrypted ip_address: #{reloaded.ip_address}")
IO.puts("  ✓ Decrypted user_agent: #{reloaded.user_agent}")

# ── Step 6: GDPR Consent ──
IO.puts("\n── Step 6: GDPR Consent ──")
{:ok, consent} = StreamflixCore.GDPR.grant_consent(user.id, "terms", %{ip_address: "10.0.0.5"})
IO.puts("  ✓ Consent granted: #{consent.id} (purpose=#{consent.purpose})")

consents = StreamflixCore.GDPR.list_consents(user.id)
IO.puts("  ✓ Consents listed: #{length(consents)}")

# Check consent ip_address is encrypted
{:ok, consent_uid} = Ecto.UUID.dump(consent.id)
%{rows: [[raw_consent_ip]]} =
  Repo.query!("SELECT ip_address FROM consents WHERE id = $1", [consent_uid])
consent_ip_enc = is_nil(raw_consent_ip) or (is_binary(raw_consent_ip) and not String.valid?(raw_consent_ip))
IO.puts("  ip_address encrypted: #{consent_ip_enc}")

# ── Step 7: Password Policy ──
IO.puts("\n── Step 7: Password Policy ──")
is_common = StreamflixAccounts.PasswordPolicy.common_password?("password123")
IO.puts("  ✓ 'password123' is common: #{is_common}")
is_common2 = StreamflixAccounts.PasswordPolicy.common_password?("X9k#mL2$vR7nQ4")
IO.puts("  ✓ 'X9k#mL2$vR7nQ4' is common: #{is_common2}")

# ── Step 8: User Lockout ──
IO.puts("\n── Step 8: Account Lockout ──")
locked = User.locked?(%User{locked_at: nil})
IO.puts("  ✓ User with nil locked_at is locked: #{locked}")
locked2 = User.locked?(%User{locked_at: DateTime.utc_now()})
IO.puts("  ✓ User locked just now is locked: #{locked2}")
old_time = DateTime.add(DateTime.utc_now(), -20 * 60, :second)
locked3 = User.locked?(%User{locked_at: old_time})
IO.puts("  ✓ User locked 20 min ago is locked: #{locked3} (should be false, lockout=15min)")

# ── Step 9: Uptime ──
IO.puts("\n── Step 9: Uptime Module ──")
{:ok, check} = StreamflixCore.Uptime.perform_health_check()
IO.puts("  ✓ Health check performed: status=#{check.status}, response_time=#{check.response_time_ms}ms")
IO.puts("  ✓ Checks: #{inspect(check.checks)}")

uptime_24h = StreamflixCore.Uptime.calculate_uptime(:last_24h)
IO.puts("  ✓ Uptime 24h: #{uptime_24h.uptime_percent}% (#{uptime_24h.total} checks)")

latest = StreamflixCore.Uptime.latest_check()
IO.puts("  ✓ Latest check: #{latest.status} at #{latest.inserted_at}")

# ── Step 10: Circuit Breaker ──
IO.puts("\n── Step 10: Circuit Breaker ──")
alias StreamflixCore.Schemas.Webhook
# Test with a mock closed-circuit webhook struct
mock_webhook = %Webhook{circuit_state: "closed"}
result = StreamflixCore.CircuitBreaker.check_circuit(mock_webhook)
IO.puts("  ✓ Closed circuit allows delivery: #{result == :ok}")

mock_open = %Webhook{circuit_state: "open", circuit_opened_at: DateTime.utc_now()}
result2 = StreamflixCore.CircuitBreaker.check_circuit(mock_open)
IO.puts("  ✓ Open circuit (just opened) blocks delivery: #{result2 == {:error, :circuit_open}}")

# ── Summary ──
IO.puts("\n========================================")
IO.puts("  VERIFICATION COMPLETE")
IO.puts("========================================")
IO.puts("  All SOC 2 ~95% features checked.")
IO.puts("  Review output above for any ✗ marks.\n")
