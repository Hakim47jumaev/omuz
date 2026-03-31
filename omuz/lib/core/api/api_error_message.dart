import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';

/// Flattens DRF-style validation maps (e.g. `{ "email": ["invalid"] }`, nested lists).
String? _drfFieldErrorsMessage(Map<dynamic, dynamic> map) {
  final parts = <String>[];

  void walk(String prefix, Object? v) {
    if (v is List) {
      for (final x in v) {
        if (x is Map) {
          x.forEach((k, iv) => walk(
                prefix.isEmpty ? '$k' : '$prefix.$k',
                iv,
              ));
        } else {
          final s = x.toString();
          if (s.isNotEmpty) {
            parts.add(prefix.isEmpty ? s : '$prefix: $s');
          }
        }
      }
    } else if (v is Map) {
      v.forEach((k, iv) => walk(
            prefix.isEmpty ? '$k' : '$prefix.$k',
            iv,
          ));
    } else if (v != null) {
      final s = v.toString();
      if (s.isNotEmpty) {
        parts.add(prefix.isEmpty ? s : '$prefix: $s');
      }
    }
  }

  map.forEach((k, v) {
    if (k == 'detail') return;
    walk('$k', v);
  });
  if (parts.isEmpty) return null;
  return parts.join(' ');
}

String? _messageFromDrfMap(Map<dynamic, dynamic> d) {
  final detail = d['detail'];
  if (detail is String && detail.isNotEmpty) return detail;
  if (detail is List && detail.isNotEmpty) {
    return detail.map((x) => x.toString()).join(', ');
  }
  final fieldMsg = _drfFieldErrorsMessage(d);
  if (fieldMsg != null && fieldMsg.isNotEmpty) return fieldMsg;
  final phoneErr = d['phone'];
  if (phoneErr is List && phoneErr.isNotEmpty) {
    return phoneErr.first.toString();
  }
  return null;
}

/// Dio may give [Map], JSON [String], or a [List] (e.g. `["detail"]`).
String? _messageFromResponseData(Object? data) {
  if (data == null) return null;
  if (data is Map) {
    return _messageFromDrfMap(data);
  }
  if (data is List) {
    if (data.isEmpty) return null;
    final parts = data
        .map((x) => x.toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
  if (data is String) {
    final t = data.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('{') || t.startsWith('[')) {
      try {
        final decoded = jsonDecode(t) as Object?;
        return _messageFromResponseData(decoded);
      } catch (_) {
        /* fall through */
      }
    }
    final lower = t.toLowerCase();
    if (lower.contains('<!doctype') || lower.contains('<html')) {
      return 'Server returned HTML instead of JSON — check API URL and that '
          'the backend is running.';
    }
    return t.length > 400 ? '${t.substring(0, 400)}…' : t;
  }
  return null;
}

bool _dioUnderlyingLooksLikeClosedSocket(DioException e) {
  final o = e.error;
  if (o == null) return false;
  final s = o.toString().toLowerCase();
  return s.contains('connection closed before full header') ||
      s.contains('connection reset by peer') ||
      s.contains('broken pipe') ||
      s.contains('socketexception');
}

bool _dioLooksLikeTransportFailure(DioException e) {
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return true;
  }
  if (e.type == DioExceptionType.unknown &&
      e.response == null &&
      _dioUnderlyingLooksLikeClosedSocket(e)) {
    return true;
  }
  return false;
}

String apiErrorMessage(Object e) {
  if (e is DioException) {
    final fromBody = _messageFromResponseData(e.response?.data);
    if (fromBody != null && fromBody.isNotEmpty) {
      return fromBody;
    }
    final code = e.response?.statusCode;
    final reason = e.response?.statusMessage;
    if (code != null) {
      if (reason != null && reason.isNotEmpty) {
        return 'Server error ($code): $reason';
      }
      return 'Server error ($code).';
    }
    if (_dioLooksLikeTransportFailure(e)) {
      final attempted = e.requestOptions.uri.toString();
      if (defaultTargetPlatform == TargetPlatform.android &&
          AppConstants.apiUrlLooksLikeEmulatorBridge) {
        return '10.0.2.2 is only for the Android emulator. On a real phone run '
            'scripts/dev.ps1 from the project folder (USB + adb reverse).';
      }
      if (defaultTargetPlatform == TargetPlatform.android &&
          (attempted.contains('127.0.0.1') ||
              attempted.contains('localhost'))) {
        if (AppConstants.adbReverse) {
          return 'Cannot reach the API over USB. On your PC: run '
              'scripts/start-api.ps1, then scripts/dev.ps1 from the OMuz folder '
              '(adb reverse tcp:8000).';
        }
        return '127.0.0.1 on the phone needs adb reverse. From the OMuz folder '
            'run scripts/dev.ps1 with USB, or: adb reverse tcp:8000 tcp:8000';
      }
      if (attempted.contains('192.168.')) {
        return 'Cannot reach the API over Wi‑Fi. Use the same network as the PC, '
            'run scripts/start-api.ps1, and allow TCP 8000 (scripts/open-firewall-8000.ps1). '
            'Or try: scripts/dev.ps1 -Lan';
      }
      return 'No connection. On the PC run scripts/start-api.ps1, then connect '
          'the phone and run scripts/dev.ps1 from the OMuz folder.';
    }
    if (e.type == DioExceptionType.unknown && e.error != null) {
      final t = e.error.toString();
      if (t.isNotEmpty && t != 'null') {
        return t.length > 200 ? '${t.substring(0, 200)}…' : t;
      }
    }
    return e.message ?? e.toString();
  }
  return e.toString();
}
