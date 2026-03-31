import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class QuizRepository {
  final _dio = ApiClient().dio;

  Future<Map<String, dynamic>> getQuizByLesson(int lessonId) async {
    final res = await _dio.get(Endpoints.quizByLesson(lessonId));
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitQuiz(
      int quizId, Map<String, int> answers, {required bool confirmReadingCheckpoint}) async {
    final res = await _dio.post(
      Endpoints.quizSubmit(quizId),
      data: {
        'answers': answers,
        'confirm_reading_checkpoint': confirmReadingCheckpoint,
      },
    );
    return res.data as Map<String, dynamic>;
  }
}
