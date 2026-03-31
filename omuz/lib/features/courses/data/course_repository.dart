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

  Future<Map<String, dynamic>> getSubscription(int courseId) async {
    final res = await _dio.get(Endpoints.subscription(courseId));
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> purchaseCourse(int courseId) async {
    final res = await _dio.post(Endpoints.purchase(courseId));
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> renewCourse(int courseId, int days) async {
    final res = await _dio.post(Endpoints.renew(courseId), data: {'days': days});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitCourseReview(int courseId, int stars) async {
    final res = await _dio.post(
      Endpoints.courseReview(courseId),
      data: {'stars': stars},
    );
    return res.data as Map<String, dynamic>;
  }
}
