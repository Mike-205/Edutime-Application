import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification.dart';

/// Device-token registration + in-app notification history. Reads/writes go
/// directly through the client under RLS (a user only ever sees/marks their own
/// notifications, and can only register their own device token).
class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  /// Upserts the current user's FCM device token so dispatch-fcm can reach it.
  /// Own-row RLS guarantees a client can't register a token for anyone else.
  Future<void> registerDeviceToken(String token, {String? platform}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('device_tokens').upsert({
      'token': token,
      'user_id': uid,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> removeDeviceToken(String token) =>
      _client.from('device_tokens').delete().eq('token', token);

  /// Live stream of the signed-in user's notifications, newest first.
  Stream<List<NotificationItem>> watchMine() {
    final uid = _client.auth.currentUser?.id;
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid ?? '')
        .order('created_at')
        .map((rows) {
          final items = rows.map(NotificationItem.fromMap).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  Future<void> markRead(String id) => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id);

  Future<void> markAllRead() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', uid)
        .isFilter('read_at', null);
  }
}
