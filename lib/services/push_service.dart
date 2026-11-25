import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'api.dart';

class PushService {
  static final shared = PushService();
  StreamSubscription<String>? _refresh;
  Future<bool> enable() async {
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      return false;
    }
    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await Api.shared.run('registerDevice', {'token': token});
    }
    _refresh ??= FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      Api.shared
          .run('registerDevice', {'token': t})
          .catchError((Object e) => <String, dynamic>{});
    });
    return true;
  }

  Future<void> logout() async {
    await _refresh?.cancel();
    _refresh = null;
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      return;
    }
    try {
      final t = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 3),
      );
      if (t != null) {
        await Api.shared
            .run('unregisterDevice', {'token': t})
            .timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
    try {
      await FirebaseMessaging.instance.deleteToken().timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {}
  }
}
