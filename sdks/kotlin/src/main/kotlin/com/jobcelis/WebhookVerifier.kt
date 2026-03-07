package com.jobcelis

import java.security.MessageDigest
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Verifies webhook signatures using HMAC-SHA256 with constant-time comparison.
 */
object WebhookVerifier {

    /**
     * Verify a webhook signature.
     *
     * @param secret The webhook signing secret.
     * @param body The raw request body string.
     * @param signature The signature from the X-Webhook-Signature header.
     * @return true if the signature is valid.
     */
    fun verify(secret: String, body: String, signature: String): Boolean {
        return try {
            val mac = Mac.getInstance("HmacSHA256")
            mac.init(SecretKeySpec(secret.toByteArray(), "HmacSHA256"))
            val hash = mac.doFinal(body.toByteArray())
            val expected = hash.joinToString("") { "%02x".format(it) }
            MessageDigest.isEqual(expected.toByteArray(), signature.toByteArray())
        } catch (e: Exception) {
            false
        }
    }
}
