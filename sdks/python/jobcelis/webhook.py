"""Webhook signature verification for Jobcelis."""

from __future__ import annotations

import base64
import hashlib
import hmac


def verify_webhook_signature(secret: str, body: str | bytes, signature: str) -> bool:
    """
    Verify a webhook signature from Jobcelis.

    Args:
        secret: The webhook secret (from webhook configuration)
        body: The raw request body, exactly as received (``bytes`` or ``str``)
        signature: The value of the X-Signature header (format: "sha256=<base64>")

    Returns:
        True if the signature is valid

    Example:
        from jobcelis import verify_webhook_signature

        @app.route('/webhook', methods=['POST'])
        def handle_webhook():
            is_valid = verify_webhook_signature(
                secret='your_webhook_secret',
                body=request.get_data(),
                signature=request.headers.get('X-Signature', '')
            )

            if not is_valid:
                return 'Invalid signature', 401

            event = request.get_json()
            print(f"Received: {event['topic']}")
            return 'OK', 200
    """
    if not secret or not body or not isinstance(signature, str) or not signature:
        return False

    prefix = "sha256="
    if not signature.startswith(prefix):
        return False

    # Compare the Base64 text itself (padding optional), never the decoded bytes
    received_sig = signature[len(prefix):].rstrip("=").encode("utf-8")
    raw = body if isinstance(body, (bytes, bytearray)) else body.encode("utf-8")

    expected_bytes = hmac.new(secret.encode("utf-8"), raw, hashlib.sha256).digest()
    expected_sig = base64.b64encode(expected_bytes).rstrip(b"=")

    return hmac.compare_digest(received_sig, expected_sig)
