# Webhook Signature Verification

Jobcelis signs every webhook delivery with HMAC-SHA256. Always verify signatures to ensure the request comes from Jobcelis and hasn't been tampered with.

## How it works

1. Jobcelis computes `HMAC-SHA256(webhook_secret, raw_body)`
2. Base64 encodes the result (no padding)
3. Sends it in the `X-Signature` header as `sha256=<base64>`

## Verification by language

### Node.js / TypeScript

```javascript
const crypto = require('crypto');

function verifySignature(secret, body, signature) {
  if (!signature.startsWith('sha256=')) return false;

  const received = signature.slice(7);
  const expected = crypto
    .createHmac('sha256', secret)
    .update(body)
    .digest('base64')
    .replace(/=+$/, '');

  const a = Buffer.from(received, 'base64');
  const b = Buffer.from(expected, 'base64');
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

// Express
app.post('/webhook', express.raw({ type: 'application/json' }), (req, res) => {
  const valid = verifySignature(
    'your_secret',
    req.body.toString(),
    req.headers['x-signature']
  );
  if (!valid) return res.status(401).send('Invalid signature');
  // process event...
  res.status(200).send('OK');
});
```

### Python

```python
import base64
import hashlib
import hmac

def verify_signature(secret: str, body: str, signature: str) -> bool:
    if not signature.startswith('sha256='):
        return False

    received = signature[7:]
    expected_bytes = hmac.new(
        secret.encode(),
        body.encode(),
        hashlib.sha256,
    ).digest()
    expected = base64.b64encode(expected_bytes).rstrip(b'=').decode()
    return hmac.compare_digest(received, expected)

# Flask
@app.route('/webhook', methods=['POST'])
def webhook():
    valid = verify_signature(
        'your_secret',
        request.get_data(as_text=True),
        request.headers.get('X-Signature', '')
    )
    if not valid:
        return 'Invalid signature', 401
    # process event...
    return 'OK', 200
```

### Go

```go
package main

import (
    "crypto/hmac"
    "crypto/sha256"
    "encoding/base64"
    "net/http"
    "strings"
)

func verifySignature(secret, body, signature string) bool {
    if !strings.HasPrefix(signature, "sha256=") {
        return false
    }
    received := signature[7:]

    mac := hmac.New(sha256.New, []byte(secret))
    mac.Write([]byte(body))
    expected := base64.RawStdEncoding.EncodeToString(mac.Sum(nil))

    return hmac.Equal([]byte(received), []byte(expected))
}

func webhookHandler(w http.ResponseWriter, r *http.Request) {
    body, _ := io.ReadAll(r.Body)
    valid := verifySignature(
        "your_secret",
        string(body),
        r.Header.Get("X-Signature"),
    )
    if !valid {
        http.Error(w, "Invalid signature", 401)
        return
    }
    // process event...
    w.WriteHeader(200)
}
```

### Ruby

```ruby
require 'openssl'
require 'base64'

def verify_signature(secret, body, signature)
  return false unless signature&.start_with?('sha256=')

  received = signature[7..]
  expected = Base64.strict_encode64(
    OpenSSL::HMAC.digest('sha256', secret, body)
  ).delete('=')

  Rack::Utils.secure_compare(received, expected)
end

# Sinatra
post '/webhook' do
  body = request.body.read
  valid = verify_signature(
    'your_secret',
    body,
    request.env['HTTP_X_SIGNATURE']
  )
  halt 401, 'Invalid signature' unless valid
  # process event...
  status 200
end
```

### PHP

```php
function verifySignature(string $secret, string $body, string $signature): bool {
    if (strpos($signature, 'sha256=') !== 0) {
        return false;
    }

    $received = substr($signature, 7);
    $expected = rtrim(base64_encode(
        hash_hmac('sha256', $body, $secret, true)
    ), '=');

    return hash_equals($received, $expected);
}

// Usage
$body = file_get_contents('php://input');
$signature = $_SERVER['HTTP_X_SIGNATURE'] ?? '';

if (!verifySignature('your_secret', $body, $signature)) {
    http_response_code(401);
    exit('Invalid signature');
}

$event = json_decode($body, true);
// process event...
http_response_code(200);
```

## Security best practices

- Always use **timing-safe comparison** (not `==` or `===`)
- Verify the **raw body**, not a re-serialized version
- Reject requests with missing or invalid signatures
- Store your webhook secret securely (environment variable)
