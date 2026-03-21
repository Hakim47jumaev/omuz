import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import 'package:dio/dio.dart';

class AiRepository {
  final _dio = ApiClient().dio;

  Future<Map<String, dynamic>> askMentor({
    required String message,
    required List<Map<String, String>> history,
    String? courseTitle,
    String? lessonTitle,
  }) async {
    try {
      final res = await _dio.post(
        Endpoints.aiMentorAsk,
        data: {
          'message': message,
          'history': history,
          if (courseTitle != null && courseTitle.trim().isNotEmpty)
            'course_title': courseTitle,
          if (lessonTitle != null && lessonTitle.trim().isNotEmpty)
            'lesson_title': lessonTitle,
        },
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) {
          throw Exception(detail);
        }
        final messageError = data['message'];
        if (messageError is List && messageError.isNotEmpty) {
          throw Exception(messageError.first.toString());
        }
      }
      rethrow;
    }
  }
}
