import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class CourseRepository {
  final _dio = ApiClient().dio;

  Future<Map<String, dynamic>> getCourseDetail(int id) async {
    final res = await _dio.get(Endpoints.courseDetail(id));
    return res.data as Map<String, dynamic>;
  }

  Future<Set<int>> getCompletedLessonIds(int courseId) async {
    try {
      final res = await _dio.get(Endpoints.courseProgress(courseId));
      final ids = (res.data['completed_lesson_ids'] as List<dynamic>)
          .map((e) => e as int)
          .toSet();
      return ids;
    } catch (_) {
      return {};
    }
  }
}
