using System.Security.Cryptography;
using System.Text;

namespace Jobcelis;

/// <summary>
/// Verify webhook signatures using HMAC-SHA256.
/// </summary>
public static class WebhookVerifier
{
    /// <summary>
    /// Verify that a webhook request body matches the provided HMAC-SHA256 signature.
    /// </summary>
    /// <param name="secret">The webhook signing secret.</param>
    /// <param name="body">The raw request body.</param>
    /// <param name="signature">The signature from the X-Signature header.</param>
    /// <returns>True if the signature is valid.</returns>
    public static bool Verify(string secret, string body, string signature)
    {
        if (string.IsNullOrEmpty(signature)) return false;

        var keyBytes = Encoding.UTF8.GetBytes(secret);
        var bodyBytes = Encoding.UTF8.GetBytes(body);

        using var hmac = new HMACSHA256(keyBytes);
        var hash = hmac.ComputeHash(bodyBytes);
        var expected = Convert.ToHexString(hash).ToLowerInvariant();

        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(expected),
            Encoding.UTF8.GetBytes(signature)
        );
    }
}
