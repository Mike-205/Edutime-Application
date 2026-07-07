import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../data/repositories/notification_repository.dart';

/// Registers this device's FCM token so `dispatch-fcm` can reach it, and keeps
/// it fresh. Fully guarded: if Firebase isn't configured (e.g. no
/// google-services.json in a dev build), push simply stays off — the in-app
/// notification history still works, since it reads the DB, not FCM.
///
/// Call [start] once the user is authenticated (the token is stored against
/// their user id). Idempotent.
class PushService {
  PushService(this._repository);

  final NotificationRepository _repository;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) {
        await _repository.registerDeviceToken(
          token,
          platform: defaultTargetPlatform.name,
        );
      }
      messaging.onTokenRefresh.listen(
        (t) => _repository.registerDeviceToken(
          t,
          platform: defaultTargetPlatform.name,
        ),
      );
    } catch (e) {
      _started = false; // let it retry once Firebase is configured
      debugPrint('Push notifications disabled: $e');
    }
  }
}
