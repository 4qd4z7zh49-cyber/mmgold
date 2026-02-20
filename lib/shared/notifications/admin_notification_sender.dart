import '../supabase/supabase_provider.dart';
import 'notification_destination.dart';

class AdminNotificationSender {
  static const String _functionName = 'send-push';

  Future<void> send({
    required String title,
    required String body,
    required String target,
    required String type,
    Map<String, String>? data,
  }) async {
    final response = await SupabaseProvider.client.functions.invoke(
      _functionName,
      body: <String, dynamic>{
        'title': title.trim(),
        'body': body.trim(),
        'target': NotificationDestination.normalize(target),
        'type': type.trim().isEmpty ? 'admin_custom' : type.trim(),
        'payload': data ?? <String, String>{},
      },
    );

    if (response.status < 200 || response.status >= 300) {
      throw Exception(
        'send-push failed (${response.status}): ${response.data}',
      );
    }
  }
}
