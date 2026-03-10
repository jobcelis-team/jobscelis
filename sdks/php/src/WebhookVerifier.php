<?php

declare(strict_types=1);

namespace Jobcelis;

/**
 * Verify webhook signatures using HMAC-SHA256 (Base64, no padding).
 */
class WebhookVerifier
{
    /**
     * Verify that a webhook request body matches the provided HMAC-SHA256 signature.
     *
     * @param string $secret  The webhook signing secret.
     * @param string $body    The raw request body.
     * @param string $signature The signature from the X-Signature header (format: "sha256=<base64>").
     * @return bool True if the signature is valid.
     */
    public static function verify(string $secret, string $body, string $signature): bool
    {
        $prefix = 'sha256=';
        if (!str_starts_with($signature, $prefix)) {
            return false;
        }

        $receivedSig = substr($signature, strlen($prefix));
        $hash = hash_hmac('sha256', $body, $secret, true);
        $expected = rtrim(base64_encode($hash), '=');

        return hash_equals($expected, $receivedSig);
    }
}
