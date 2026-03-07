import Foundation
import CryptoKit

/// Verify webhook signatures using HMAC-SHA256.
public enum WebhookVerifier {
    /// Verify that a webhook request body matches the provided HMAC-SHA256 signature.
    ///
    /// - Parameters:
    ///   - secret: The webhook signing secret.
    ///   - body: The raw request body.
    ///   - signature: The signature from the X-Signature header.
    /// - Returns: `true` if the signature is valid.
    public static func verify(secret: String, body: String, signature: String) -> Bool {
        guard !signature.isEmpty else { return false }

        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(body.utf8), using: key)
        let expected = mac.map { String(format: "%02x", $0) }.joined()

        guard expected.count == signature.count else { return false }

        // Constant-time comparison
        var result: UInt8 = 0
        for (a, b) in zip(expected.utf8, signature.utf8) {
            result |= a ^ b
        }
        return result == 0
    }
}
