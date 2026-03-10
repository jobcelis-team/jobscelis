package com.jobcelis

import java.security.MessageDigest
import java.util.Base64
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Verifies webhook signatures using HMAC-SHA256 (Base64, no padding) with constant-time comparison.
 */
object WebhookVerifier {

    private const val PREFIX = "sha256="

    /**
     * Verify a webhook signature.
     *
     * @param secret The webhook signing secret.
     * @param body The raw request body string.
     * @param signature The signature from the X-Signature header (format: "sha256=<base64>").
     * @return true if the signature is valid.
     */
    fun verify(secret: String, body: String, signature: String): Boolean {
        return try {
            if (!signature.startsWith(PREFIX)) return false

            val receivedSig = signature.removePrefix(PREFIX)

            val mac = Mac.getInstance("HmacSHA256")
            mac.init(SecretKeySpec(secret.toByteArray(), "HmacSHA256"))
            val hash = mac.doFinal(body.toByteArray())
            val expected = Base64.getEncoder().withoutPadding().encodeToString(hash)

            MessageDigest.isEqual(expected.toByteArray(), receivedSig.toByteArray())
        } catch (e: Exception) {
            false
        }
    }
}
