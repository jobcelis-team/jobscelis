package jobcelis

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"strings"
)

// VerifySignature verifies an incoming webhook signature.
//
// Parameters:
//   - secret: The webhook secret configured when creating the webhook
//   - body: The raw request body bytes
//   - signature: The value of the X-Signature header
//
// Returns true if the signature is valid.
func VerifySignature(secret string, body []byte, signature string) bool {
	if !strings.HasPrefix(signature, "sha256=") {
		return false
	}
	received := signature[7:]

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	expected := base64.RawStdEncoding.EncodeToString(mac.Sum(nil))

	return hmac.Equal([]byte(received), []byte(expected))
}
