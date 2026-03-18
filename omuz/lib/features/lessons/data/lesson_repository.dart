import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class LessonRepository {
  final _dio = ApiClient().dio;

  Future<Map<String, dynamic>> getLesson(int id) async {
    final res = await _dio.get(Endpoints.lessonDetail(id));
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLessonStatus(int lessonId) async {
    try {
      final res = await _dio.get(Endpoints.lessonStatus(lessonId));
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return {
        'video_watched': false,
        'quiz_passed': false,
        'quiz_score': 0,
        'is_completed': false,
      };
    }
  }

  Future<Map<String, dynamic>> markVideoWatched(int lessonId) async {
    final res = await _dio.post(Endpoints.markVideo, data: {'lesson_id': lessonId});
    return res.data as Map<String, dynamic>;
  }
}
