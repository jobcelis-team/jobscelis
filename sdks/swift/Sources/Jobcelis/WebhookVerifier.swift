import Foundation
import CryptoKit

/// Verify webhook signatures using HMAC-SHA256 (Base64, no padding).
public enum WebhookVerifier {
    /// Verify that a webhook request body matches the provided HMAC-SHA256 signature.
    ///
    /// - Parameters:
    ///   - secret: The webhook signing secret.
    ///   - body: The raw request body.
    ///   - signature: The signature from the X-Signature header (format: "sha256=<base64>").
    /// - Returns: `true` if the signature is valid.
    public static func verify(secret: String, body: String, signature: String) -> Bool {
        let prefix = "sha256="
        guard signature.hasPrefix(prefix) else { return false }

        let receivedSig = String(signature.dropFirst(prefix.count))
        guard !receivedSig.isEmpty else { return false }

        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(body.utf8), using: key)
        let expected = Data(mac).base64EncodedString().replacingOccurrences(of: "=", with: "")

        guard expected.count == receivedSig.count else { return false }

        // Constant-time comparison
        var result: UInt8 = 0
        for (a, b) in zip(expected.utf8, receivedSig.utf8) {
            result |= a ^ b
        }
        return result == 0
    }
}
