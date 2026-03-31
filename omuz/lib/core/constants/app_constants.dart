import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'Omuz';

  /// After a successful run with `--dart-define` / dev.ps1, base URL is cached (debug).
  /// Hot restart picks up URL without rebuilding assets.
  static const String _prefsKeyApiBaseCached = 'omuz_api_base_cached';

  static const String _apiFromEnv = String.fromEnvironment('API_BASE_URL');
  static const String _hostFromEnv = String.fromEnvironment('API_HOST');

  /// `scripts/dev.ps1` (default USB) sets `--dart-define=OMUZ_ADB=true` (adb reverse).
  static const bool adbReverse =
      bool.fromEnvironment('OMUZ_ADB', defaultValue: false);

  static String _baseUrl = '';

  static bool apiUrlLooksLikeEmulatorBridge = false;

  static String get baseUrl => _baseUrl.isEmpty ? _fallbackUrl() : _baseUrl;

  static String _fallbackUrl() {
    if (kIsWeb) return 'http://127.0.0.1:8000/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  static Future<void> init() async {
    String? resolved;

    if (_apiFromEnv.isNotEmpty) {
      resolved = _normalizeApiBaseUrl(_apiFromEnv);
    } else if (_hostFromEnv.isNotEmpty) {
      final h = _hostFromEnv.trim();
      resolved = h.contains(':')
          ? _normalizeApiBaseUrl('http://$h')
          : _normalizeApiBaseUrl('http://$h:8000');
    }

    if (resolved == null || resolved.isEmpty) {
      if (kIsWeb) {
        resolved = 'http://127.0.0.1:8000/api/v1';
      } else {
        try {
          final raw = await rootBundle.loadString('assets/local_api.json');
          final j = jsonDecode(raw) as Map<String, dynamic>;
          final url = (j['api_base_url'] as String?)?.trim() ?? '';
          if (url.isNotEmpty) {
            resolved = _normalizeApiBaseUrl(url);
          }
        } catch (e) {
          debugPrint('[Omuz] local_api.json: $e');
        }
      }
    }

    if ((resolved == null || resolved.isEmpty) && kDebugMode) {
      try {
        final p = await SharedPreferences.getInstance();
        final c = p.getString(_prefsKeyApiBaseCached)?.trim();
        if (c != null && c.isNotEmpty) {
          resolved = _normalizeApiBaseUrl(c);
        }
      } catch (_) {}
    }

    if (resolved == null || resolved.isEmpty) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final info = await DeviceInfoPlugin().androidInfo;
          resolved = info.isPhysicalDevice
              ? 'http://127.0.0.1:8000/api/v1'
              : 'http://10.0.2.2:8000/api/v1';
        } catch (_) {
          resolved = 'http://127.0.0.1:8000/api/v1';
        }
      } else {
        resolved = 'http://127.0.0.1:8000/api/v1';
      }
    }

    _baseUrl = resolved;
    await _syncAndroidFlags();

    if (kDebugMode && _baseUrl.isNotEmpty && !apiUrlLooksLikeEmulatorBridge) {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(_prefsKeyApiBaseCached, _baseUrl);
      } catch (_) {}
    }
  }

  static Future<void> _syncAndroidFlags() async {
    apiUrlLooksLikeEmulatorBridge = false;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      apiUrlLooksLikeEmulatorBridge =
          info.isPhysicalDevice && _baseUrl.contains('10.0.2.2');
    } catch (_) {}
  }

  static String _normalizeApiBaseUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('/api/v1')) return s;
    if (s.contains('/api/')) return s;
    return '$s/api/v1';
  }
}
