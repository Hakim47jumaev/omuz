import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class AuthRepository {
  final _dio = ApiClient().dio;

  Future<bool> sendOtp(String phone) async {
    final response = await _dio.post(Endpoints.sendOtp, data: {'phone': phone});
    final data = response.data as Map<String, dynamic>;
    return data['is_new'] as bool;
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    String firstName = '',
    String lastName = '',
  }) async {
    final response = await _dio.post(Endpoints.verifyOtp, data: {
      'phone': phone,
      'otp': otp,
      'first_name': firstName,
      'last_name': lastName,
    });
    final data = response.data as Map<String, dynamic>;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', data['access']);
    await prefs.setString('refresh_token', data['refresh']);

    final user = data['user'] as Map<String, dynamic>;
    await prefs.setBool('is_staff', user['is_staff'] == true);
    return user;
  }

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
}
