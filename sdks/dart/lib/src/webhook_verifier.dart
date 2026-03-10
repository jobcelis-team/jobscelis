import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Verifies webhook signatures using HMAC-SHA256 (Base64, no padding) with constant-time comparison.
///
/// Use [WebhookVerifier.verify] to validate incoming webhook requests.
class WebhookVerifier {
  /// Private constructor -- use the static [verify] method.
  WebhookVerifier._();

  static const String _prefix = 'sha256=';

  /// Verify a webhook signature.
  ///
  /// The [signature] should be the full X-Signature header value (format: "sha256=<base64>").
  /// Returns `true` if the signature is valid.
  static bool verify(String secret, String body, String signature) {
    if (!signature.startsWith(_prefix)) return false;

    final receivedSig = signature.substring(_prefix.length);
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(body));
    final expected = base64Encode(digest.bytes).replaceAll('=', '');

    if (expected.length != receivedSig.length) return false;

    var result = 0;
    for (var i = 0; i < expected.length; i++) {
      result |= expected.codeUnitAt(i) ^ receivedSig.codeUnitAt(i);
    }
    return result == 0;
  }
}
