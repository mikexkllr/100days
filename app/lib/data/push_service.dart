import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'social_backend.dart';

/// Push notifications from friends, through Firebase Cloud Messaging.
///
/// Off unless the build carries a Firebase configuration — the values come
/// from `--dart-define-from-file` (in CI: GitHub secrets), never from the
/// repository, so a self-hosted build uses its own Firebase project or none.
class PushService {
  PushService._();

  static StreamSubscription<String>? _refresh;

  static FirebaseOptions? _options() {
    const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const String senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
    const String androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
    const String iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
    final String appId = Platform.isIOS ? iosAppId : androidAppId;
    if (apiKey.isEmpty || projectId.isEmpty || senderId.isEmpty || appId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      iosBundleId: Platform.isIOS ? 'com.hundreddays.hundredDays' : null,
    );
  }

  static bool get isConfigured =>
      (Platform.isAndroid || Platform.isIOS) && _options() != null;

  /// Registers this device with the account. Safe to call on every start;
  /// does nothing without a configuration.
  ///
  /// It only *asks* for permission when [askPermission] is set — the app
  /// asks once, with an explanation of what it will send (see
  /// `ReminderPermissionCard`), not as a bare system dialog right after
  /// signing in. Without permission the device is not registered.
  static Future<void> start(
    SocialBackend social, {
    bool askPermission = false,
  }) async {
    final FirebaseOptions? options = _options();
    if (options == null || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      final NotificationSettings settings = askPermission
          ? await messaging.requestPermission()
          : await messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      final String platform = Platform.isIOS ? 'ios' : 'android';
      // Registration tokens are what the `push` function sends to through
      // FCM's v1 API. The newer register()/onRegistered hands out
      // installation ids instead; switch together with the server.
      // ignore: deprecated_member_use
      final String? token = await messaging.getToken();
      if (token != null) await social.registerPushToken(token, platform: platform);
      await _refresh?.cancel();
      // ignore: deprecated_member_use
      _refresh = messaging.onTokenRefresh.listen((String fresh) =>
          unawaited(social.registerPushToken(fresh, platform: platform)));
    } on Object catch (error) {
      debugPrint('Push unavailable: $error');
    }
  }

  /// Unregisters this device, e.g. on sign-out: the next account on this
  /// phone must not get the last one's nudges, and its own registration
  /// must not collide with a token row it cannot see.
  static Future<void> stop(SupabaseClient client) async {
    await _refresh?.cancel();
    _refresh = null;
    if (_options() == null || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      if (Firebase.apps.isEmpty) return;
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      // ignore: deprecated_member_use
      final String? token = await messaging.getToken();
      if (token != null) {
        await client.from('push_tokens').delete().eq('token', token);
      }
      // ignore: deprecated_member_use
      await messaging.deleteToken();
    } on Object catch (error) {
      debugPrint('Push token not removed: $error');
    }
  }
}
