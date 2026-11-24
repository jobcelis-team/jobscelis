import { createHmac, timingSafeEqual } from 'crypto';

/**
 * Verify a webhook signature from Jobcelis.
 *
 * @param secret - The webhook secret (from webhook configuration)
 * @param body - The raw request body, exactly as received (string or Buffer)
 * @param signature - The value of the X-Signature header (format: "sha256=<base64>")
 * @returns true if the signature is valid
 *
 * @example
 * ```typescript
 * import { verifyWebhookSignature } from '@jobcelis/sdk';
 *
 * app.post('/webhook', express.raw({ type: 'application/json' }), (req, res) => {
 *   const isValid = verifyWebhookSignature(
 *     'your_webhook_secret',
 *     req.body, // raw Buffer
 *     req.headers['x-signature'] as string
 *   );
 *
 *   if (!isValid) {
 *     return res.status(401).send('Invalid signature');
 *   }
 *
 *   // Process webhook...
 *   res.status(200).send('OK');
 * });
 * ```
 */
export function verifyWebhookSignature(
  secret: string,
  body: string | Buffer,
  signature: string
): boolean {
  if (!secret || body === undefined || body === null || body.length === 0) return false;
  if (typeof signature !== 'string' || !signature) return false;

  const prefix = 'sha256=';
  if (!signature.startsWith(prefix)) return false;

  // Compare the Base64 text itself (padding optional): decoding first would ignore
  // invalid characters, so a tampered signature could still match.
  const receivedSig = signature.slice(prefix.length).replace(/=+$/, '');
  const expectedSig = createHmac('sha256', secret)
    .update(body)
    .digest('base64')
    .replace(/=+$/, '');

  const a = Buffer.from(receivedSig, 'utf8');
  const b = Buffer.from(expectedSig, 'utf8');
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}
