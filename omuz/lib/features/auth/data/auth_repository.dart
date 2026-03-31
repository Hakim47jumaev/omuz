import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error_message.dart';
import '../../../core/api/endpoints.dart';

class AuthRepository {
  final _dio = ApiClient().dio;

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return phone.trim();
    return '+$digits';
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final response =
        await _dio.post(Endpoints.sendOtp, data: {'phone': _normalizePhone(phone)});
    return (response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    String firstName = '',
    String lastName = '',
  }) async {
    final response = await _dio.post(
      Endpoints.verifyOtp,
      data: {
        'phone': _normalizePhone(phone),
        'otp': otp.trim(),
        'first_name': firstName,
        'last_name': lastName,
      },
    );
    final data = response.data as Map<String, dynamic>;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', data['access']);
    await prefs.setString('refresh_token', data['refresh']);

    final user = data['user'] as Map<String, dynamic>;
    await prefs.setBool('is_staff', user['is_staff'] == true);
    return user;
  }

  static String messageFromError(Object e) => apiErrorMessage(e);

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('access_token');
  }

  Future<bool> isStaff() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_staff') ?? false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  Future<void> registerDeviceToken(String token, {String platform = 'android'}) async {
    await _dio.post(
      Endpoints.deviceToken,
      data: {
        'token': token,
        'platform': platform,
      },
    );
  }
}
