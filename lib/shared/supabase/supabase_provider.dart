import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProvider {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static SupabaseClient? _client;

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured || _client != null) return;

    await Supabase.initialize(url: url, anonKey: anonKey);
    _client = Supabase.instance.client;
  }

  static SupabaseClient get client {
    final c = _client;
    if (c == null) {
      throw StateError(
        'Supabase is not initialized. Set SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }
    return c;
  }
}
