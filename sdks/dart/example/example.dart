import 'package:jobcelis/jobcelis.dart';

void main() async {
  // Create a client -- connects to https://jobcelis.com automatically
  final client = JobcelisClient(apiKey: 'your_api_key');

  try {
    // Send an event
    final event = await client.sendEvent('order.created', {
      'order_id': '123',
      'amount': 99.99,
    });
    print('Event sent: $event');

    // List webhooks
    final webhooks = await client.listWebhooks();
    print('Webhooks: $webhooks');

    // Verify a webhook signature
    const body = '{"topic":"order.created"}';
    const signature = 'abc123...';
    final isValid = WebhookVerifier.verify('your_secret', body, signature);
    print('Signature valid: $isValid');
  } on JobcelisException catch (e) {
    print('API error ${e.statusCode}: ${e.detail}');
  } finally {
    client.close();
  }
}
