import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PushService {
  /// Web needs `firebase_options.dart` from FlutterFire; skip when not configured.
  static Future<void> initFirebase() async {
    if (kIsWeb) {
      return;
    }
    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      if (kDebugMode) {
        final short = e is PlatformException
            ? (e.message ?? e.code)
            : e.toString().split('\n').first;
        debugPrint('[Omuz] Push off (no Firebase): $short');
      }
    }
  }

  static Future<String?> getToken() async {
    if (kIsWeb) {
      return null;
    }
    if (Firebase.apps.isEmpty) {
      return null;
    }
    try {
      final token = await FirebaseMessaging.instance.getToken();
      return token;
    } catch (e) {
      if (kDebugMode) {
        final short = e is PlatformException
            ? (e.message ?? e.code)
            : e.toString().split('\n').first;
        debugPrint('[Omuz] Push token skipped: $short');
      }
      return null;
    }
  }

  static String get platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'other';
    }
  }
}
