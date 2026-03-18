import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

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
}
