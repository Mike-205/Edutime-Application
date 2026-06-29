import 'package:supabase_flutter/supabase_flutter.dart';

/// Initializes and exposes the app-wide Supabase client.
///
/// Role-based access is enforced server-side via RLS (the client is never
/// trusted). See ARCHITECTURE.md "Access Control (RLS)".
class SupabaseClientProvider {
  const SupabaseClientProvider._();

  /// Call once during app bootstrap, before [client] is used.
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: url, publishableKey: anonKey);
  }

  /// The shared client. Throws if [initialize] has not run.
  static SupabaseClient get client => Supabase.instance.client;
}
