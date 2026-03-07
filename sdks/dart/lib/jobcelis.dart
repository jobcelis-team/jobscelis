/// Official Dart/Flutter SDK for the Jobcelis Event Infrastructure Platform.
///
/// ```dart
/// import 'package:jobcelis/jobcelis.dart';
///
/// final client = JobcelisClient(apiKey: 'your_api_key');
/// final event = await client.sendEvent('order.created', {'order_id': '123'});
/// ```
library jobcelis;

export 'src/client.dart';
export 'src/exception.dart';
export 'src/webhook_verifier.dart';
