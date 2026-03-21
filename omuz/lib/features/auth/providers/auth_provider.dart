import 'package:flutter/material.dart';
import '../../../core/services/push_service.dart';

import '../data/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final _repo = AuthRepository();

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  String _phone = '';
  String get phone => _phone;

  bool _isNewUser = false;
  bool get isNewUser => _isNewUser;

  Map<String, dynamic>? _user;
  Map<String, dynamic>? get user => _user;

  Future<bool> sendOtp(String phone) async {
    _phone = phone;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _isNewUser = await _repo.sendOtp(phone);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _loading = false;
      _error = 'Failed to send OTP: $e';
      debugPrint('SEND OTP ERROR: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String otp,
    String firstName = '',
    String lastName = '',
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _repo.verifyOtp(
        phone: _phone,
        otp: otp,
        firstName: firstName,
        lastName: lastName,
      );
      final token = await PushService.getToken();
      if (token != null && token.isNotEmpty) {
        try {
          await _repo.registerDeviceToken(token, platform: PushService.platform);
        } catch (e) {
          debugPrint('REGISTER DEVICE TOKEN ERROR: $e');
        }
      }
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _loading = false;
      _error = 'Verify failed: $e';
      debugPrint('VERIFY OTP ERROR: $e');
      notifyListeners();
      return false;
    }
  }

  bool _isStaff = false;
  bool get isStaff => _isStaff;

  Future<bool> isLoggedIn() => _repo.isLoggedIn();

  Future<void> checkStaff() async {
    _isStaff = await _repo.isStaff();
    notifyListeners();
  }

  Future<void> logout() async {
    await _repo.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> registerDeviceToken(String token, {String platform = 'android'}) async {
    try {
      await _repo.registerDeviceToken(token, platform: platform);
    } catch (e) {
      debugPrint('REGISTER DEVICE TOKEN ERROR: $e');
    }
  }
}
