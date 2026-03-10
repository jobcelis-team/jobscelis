using System.Security.Cryptography;
using System.Text;

namespace Jobcelis;

/// <summary>
/// Verify webhook signatures using HMAC-SHA256.
///
/// The Jobcelis backend signs webhook payloads with HMAC-SHA256, Base64-encoded
/// without padding, and sends the signature in the <c>x-signature</c> header
/// with the format <c>sha256=&lt;base64_no_padding&gt;</c>.
/// </summary>
public static class WebhookVerifier
{
    private const string Prefix = "sha256=";

    /// <summary>
    /// Verify that a webhook request body matches the provided HMAC-SHA256 signature.
    /// </summary>
    /// <param name="secret">The webhook signing secret.</param>
    /// <param name="body">The raw request body.</param>
    /// <param name="signature">The signature from the X-Signature header (format: "sha256=&lt;base64&gt;").</param>
    /// <returns>True if the signature is valid.</returns>
    public static bool Verify(string secret, string body, string signature)
    {
        if (string.IsNullOrEmpty(secret) || string.IsNullOrEmpty(body) || string.IsNullOrEmpty(signature))
            return false;

        if (!signature.StartsWith(Prefix, StringComparison.Ordinal))
            return false;

        var receivedSig = signature[Prefix.Length..];

        var keyBytes = Encoding.UTF8.GetBytes(secret);
        var bodyBytes = Encoding.UTF8.GetBytes(body);

        using var hmac = new HMACSHA256(keyBytes);
        var hash = hmac.ComputeHash(bodyBytes);

        // Base64 without padding
        var expectedSig = Convert.ToBase64String(hash).TrimEnd('=');

        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(expectedSig),
            Encoding.UTF8.GetBytes(receivedSig)
        );
    }
}
