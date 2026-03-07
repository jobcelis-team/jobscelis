package com.jobcelis;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

/**
 * Verifies webhook signatures using HMAC-SHA256 with constant-time comparison.
 */
public final class WebhookVerifier {

    private WebhookVerifier() {}

    /**
     * Verify a webhook signature.
     *
     * @param secret    The webhook signing secret.
     * @param body      The raw request body string.
     * @param signature The signature from the X-Webhook-Signature header.
     * @return true if the signature is valid.
     */
    public static boolean verify(String secret, String body, String signature) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(body.getBytes(StandardCharsets.UTF_8));
            String expected = bytesToHex(hash);
            return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.UTF_8),
                signature.getBytes(StandardCharsets.UTF_8)
            );
        } catch (Exception e) {
            return false;
        }
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder(bytes.length * 2);
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }
}
