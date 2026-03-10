package com.jobcelis;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;

/**
 * Verifies webhook signatures using HMAC-SHA256 (Base64, no padding) with constant-time comparison.
 */
public final class WebhookVerifier {

    private static final String PREFIX = "sha256=";

    private WebhookVerifier() {}

    /**
     * Verify a webhook signature.
     *
     * @param secret    The webhook signing secret.
     * @param body      The raw request body string.
     * @param signature The signature from the X-Signature header (format: "sha256=&lt;base64&gt;").
     * @return true if the signature is valid.
     */
    public static boolean verify(String secret, String body, String signature) {
        try {
            if (signature == null || !signature.startsWith(PREFIX)) {
                return false;
            }

            String receivedSig = signature.substring(PREFIX.length());

            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(body.getBytes(StandardCharsets.UTF_8));
            String expected = Base64.getEncoder().withoutPadding().encodeToString(hash);

            return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.UTF_8),
                receivedSig.getBytes(StandardCharsets.UTF_8)
            );
        } catch (Exception e) {
            return false;
        }
    }
}
