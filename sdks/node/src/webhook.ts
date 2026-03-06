import { createHmac, timingSafeEqual } from 'crypto';

/**
 * Verify a webhook signature from Jobcelis.
 *
 * @param secret - The webhook secret (from webhook configuration)
 * @param body - The raw request body as a string
 * @param signature - The value of the X-Signature header (format: "sha256=<base64>")
 * @returns true if the signature is valid
 *
 * @example
 * ```typescript
 * import { verifyWebhookSignature } from '@jobcelis/sdk';
 *
 * app.post('/webhook', (req, res) => {
 *   const isValid = verifyWebhookSignature(
 *     'your_webhook_secret',
 *     req.rawBody,
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
  body: string,
  signature: string
): boolean {
  if (!secret || !body || !signature) return false;

  const prefix = 'sha256=';
  if (!signature.startsWith(prefix)) return false;

  const receivedSig = signature.slice(prefix.length);
  const expectedSig = createHmac('sha256', secret)
    .update(body)
    .digest('base64')
    .replace(/=+$/, ''); // no padding

  try {
    const a = Buffer.from(receivedSig, 'base64');
    const b = Buffer.from(expectedSig, 'base64');
    if (a.length !== b.length) return false;
    return timingSafeEqual(a, b);
  } catch {
    return false;
  }
}
