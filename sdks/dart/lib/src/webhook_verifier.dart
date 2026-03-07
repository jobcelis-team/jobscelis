import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Verifies webhook signatures using HMAC-SHA256 with constant-time comparison.
class WebhookVerifier {
  /// Verify a webhook signature.
  ///
  /// Returns `true` if the signature is valid.
  static bool verify(String secret, String body, String signature) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(body));
    final expected = digest.toString();

    if (expected.length != signature.length) return false;

    var result = 0;
    for (var i = 0; i < expected.length; i++) {
      result |= expected.codeUnitAt(i) ^ signature.codeUnitAt(i);
    }
    return result == 0;
  }
}
