import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

bool _dioUnderlyingLooksLikeClosedSocket(DioException e) {
  final o = e.error;
  if (o == null) return false;
  final s = o.toString().toLowerCase();
  return s.contains('connection closed before full header') ||
      s.contains('connection reset by peer') ||
      s.contains('broken pipe') ||
      s.contains('socketexception');
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        // Ensure 4xx/5xx bodies are still parsed (DRF JSON, plain text).
        receiveDataWhenStatusError: true,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _logBaseUrl();

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          dio.options.baseUrl = AppConstants.baseUrl;
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          final bu = AppConstants.baseUrl.toLowerCase();
          final local = bu.contains('127.0.0.1') ||
              bu.contains('10.0.2.2') ||
              bu.contains('localhost') ||
              bu.contains('192.168.');
          if (local) {
            options.headers['Connection'] = 'close';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          final uri = error.requestOptions.uri.toString();
          final status = error.response?.statusCode;
          final body = error.response?.data;
          debugPrint('API ERROR [$status] $uri | $body');
          final transportLikely = error.type == DioExceptionType.connectionError ||
              (error.type == DioExceptionType.unknown &&
                  _dioUnderlyingLooksLikeClosedSocket(error));
          if (kDebugMode && transportLikely) {
            if (AppConstants.apiUrlLooksLikeEmulatorBridge) {
              debugPrint(
                '[Omuz] 10.0.2.2 is for emulator only. Real device: '
                'scripts/dev.ps1 (USB + adb reverse) or -Mode emulator on AVD.',
              );
            } else if (AppConstants.baseUrl.contains('127.0.0.1') ||
                AppConstants.baseUrl.contains('localhost')) {
              if (AppConstants.adbReverse) {
                debugPrint(
                  '[Omuz] adb: start-api.ps1 on PC, then scripts/dev.ps1 '
                  '(adb reverse tcp:8000).',
                );
              } else {
                debugPrint(
                  '[Omuz] Phone + 127.0.0.1 needs adb reverse. Run scripts/dev.ps1 '
                  'or adb reverse tcp:8000 tcp:8000 and --dart-define=OMUZ_ADB=true.',
                );
              }
            } else {
              debugPrint(
                '[Omuz] No API connection. Use scripts/dev.ps1 (USB) or set '
                'API_BASE_URL + optional OMUZ_ADB for adb reverse.',
              );
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  void _logBaseUrl() {
    if (kDebugMode) {
      debugPrint('[Omuz] API_BASE_URL → ${AppConstants.baseUrl}');
      _debugWarnLocalhostOnDevice();
    }
  }

  static void _debugWarnLocalhostOnDevice() {
    if (!kDebugMode) return;
    if (AppConstants.adbReverse) return;
    final u = AppConstants.baseUrl.toLowerCase();
    if (!u.contains('127.0.0.1') && !u.contains('localhost')) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    debugPrint(
      '[Omuz] localhost on Android needs adb reverse. Run scripts/dev.ps1 (USB).',
    );
  }
}
