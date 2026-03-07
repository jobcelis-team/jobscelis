use hmac::{Hmac, Mac};
use sha2::Sha256;
use subtle::ConstantTimeEq;

type HmacSha256 = Hmac<Sha256>;

/// Verify a webhook signature using HMAC-SHA256.
///
/// # Arguments
///
/// * `secret` - The webhook signing secret.
/// * `body` - The raw request body.
/// * `signature` - The signature from the X-Signature header.
///
/// # Returns
///
/// `true` if the signature is valid.
pub fn verify_webhook_signature(secret: &str, body: &str, signature: &str) -> bool {
    let mut mac = match HmacSha256::new_from_slice(secret.as_bytes()) {
        Ok(m) => m,
        Err(_) => return false,
    };
    mac.update(body.as_bytes());
    let result = mac.finalize();
    let expected = hex::encode(result.into_bytes());

    expected.as_bytes().ct_eq(signature.as_bytes()).into()
}
