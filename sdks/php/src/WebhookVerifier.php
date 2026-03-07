<?php

declare(strict_types=1);

namespace Jobcelis;

/**
 * Verify webhook signatures using HMAC-SHA256.
 */
class WebhookVerifier
{
    /**
     * Verify that a webhook request body matches the provided HMAC-SHA256 signature.
     *
     * @param string $secret  The webhook signing secret.
     * @param string $body    The raw request body.
     * @param string $signature The signature from the X-Signature header.
     * @return bool True if the signature is valid.
     */
    public static function verify(string $secret, string $body, string $signature): bool
    {
        $expected = hash_hmac('sha256', $body, $secret);

        return hash_equals($expected, $signature);
    }
}
