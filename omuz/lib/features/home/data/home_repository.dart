import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class HomeRepository {
  final _dio = ApiClient().dio;

  Future<List<dynamic>> getCategories() async {
    final res = await _dio.get(Endpoints.categories);
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getCourses({int? categoryId}) async {
    final params = <String, dynamic>{};
    if (categoryId != null) params['category'] = categoryId;
    final res = await _dio.get(Endpoints.courses, queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getContinueLearning() async {
    try {
      final res = await _dio.get(Endpoints.continueLearning);
      return res.data as List<dynamic>;
    } catch (_) {
      return [];
    }
  }
}
