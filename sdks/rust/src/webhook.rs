use base64::Engine;
use base64::engine::general_purpose::STANDARD_NO_PAD;
use hmac::{Hmac, Mac};
use sha2::Sha256;
use subtle::ConstantTimeEq;

type HmacSha256 = Hmac<Sha256>;

/// Verify a webhook signature using HMAC-SHA256 (Base64, no padding).
///
/// # Arguments
///
/// * `secret` - The webhook signing secret.
/// * `body` - The raw request body.
/// * `signature` - The signature from the X-Signature header (format: "sha256=<base64>").
///
/// # Returns
///
/// `true` if the signature is valid.
pub fn verify_webhook_signature(secret: &str, body: &str, signature: &str) -> bool {
    let prefix = "sha256=";
    let received_sig = match signature.strip_prefix(prefix) {
        Some(s) => s,
        None => return false,
    };

    let mut mac = match HmacSha256::new_from_slice(secret.as_bytes()) {
        Ok(m) => m,
        Err(_) => return false,
    };
    mac.update(body.as_bytes());
    let result = mac.finalize();
    let expected = STANDARD_NO_PAD.encode(result.into_bytes());

    expected.as_bytes().ct_eq(received_sig.as_bytes()).into()
}
