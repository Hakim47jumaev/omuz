import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import 'package:dio/dio.dart';

class ProfileRepository {
  final _dio = ApiClient().dio;

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _dio.get(Endpoints.profile);
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getLeaderboard() async {
    final res = await _dio.get(Endpoints.leaderboard);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getLeaderboardUser(int userId) async {
    final res = await _dio.get(Endpoints.leaderboardUser(userId));
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWallet() async {
    final res = await _dio.get(Endpoints.wallet);
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getTransactions() async {
    final res = await _dio.get(Endpoints.walletTransactions);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getNotifications() async {
    final res = await _dio.get(Endpoints.notifications);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getNotificationById(int id) async {
    final res = await _dio.get(Endpoints.notificationDetail(id));
    return res.data as Map<String, dynamic>;
  }

  Future<void> readNotification(int id) async {
    await _dio.post(Endpoints.notificationRead(id));
  }

  Future<void> readAllNotifications() async {
    await _dio.post(Endpoints.notificationsReadAll);
  }

  Future<void> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath),
    });
    await _dio.post(
      Endpoints.meAvatar,
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
      ),
    );
  }
}
