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
    final accessToken = await _requireJwtAccessToken();
    if (accessToken.isEmpty) {
      throw StateError('Not signed in. Please sign in again.');
    }

    final response = await SupabaseProvider.client.functions.invoke(
      _functionName,
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
      },
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

  Future<String> _requireJwtAccessToken() async {
    final auth = SupabaseProvider.client.auth;
    var session = auth.currentSession;

    if (session == null) {
      throw StateError('Not signed in. Please sign in again.');
    }

    // Refresh proactively so we don't send stale/rotated tokens to Edge Functions.
    try {
      final refreshed = await auth.refreshSession();
      session = refreshed.session ?? auth.currentSession ?? session;
    } catch (_) {
      // Keep current session as fallback. We'll validate below.
    }

    final current = session;
    if (current == null) {
      throw StateError('Session expired. Please sign out and sign in again.');
    }

    final raw = current.accessToken.trim();
    final token =
        raw.toLowerCase().startsWith('bearer ') ? raw.substring(7).trim() : raw;

    // Fallback to prevent sending publishable keys or malformed values
    // as Authorization bearer tokens.
    if (token.split('.').length != 3) {
      throw StateError(
          'Invalid session token. Please sign out and sign in again.');
    }

    // Validate token against Supabase Auth before invoking Edge Function.
    try {
      await auth.getUser(token);
    } catch (_) {
      throw StateError('Session expired. Please sign out and sign in again.');
    }

    return token;
  }
}
