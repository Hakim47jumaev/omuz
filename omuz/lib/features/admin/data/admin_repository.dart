import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class AdminRepository {
  final _dio = ApiClient().dio;

  // Categories
  Future<List<dynamic>> getCategories() async {
    final res = await _dio.get(Endpoints.adminCategories);
    return res.data as List<dynamic>;
  }

  Future<void> createCategory(Map<String, dynamic> data) async {
    await _dio.post(Endpoints.adminCategories, data: data);
  }

  Future<void> deleteCategory(int id) async {
    await _dio.delete(Endpoints.adminCategory(id));
  }

  // Courses
  Future<List<dynamic>> getCourses() async {
    final res = await _dio.get(Endpoints.adminCourses);
    return res.data as List<dynamic>;
  }

  Future<void> createCourse(Map<String, dynamic> data) async {
    await _dio.post(Endpoints.adminCourses, data: data);
  }

  Future<void> updateCourse(int id, Map<String, dynamic> data) async {
    await _dio.patch(Endpoints.adminCourse(id), data: data);
  }

  Future<void> deleteCourse(int id) async {
    await _dio.delete(Endpoints.adminCourse(id));
  }

  // Modules
  Future<List<dynamic>> getModules({int? courseId}) async {
    final params = <String, dynamic>{};
    if (courseId != null) params['course'] = courseId;
    final res = await _dio.get(Endpoints.adminModules, queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<void> createModule(Map<String, dynamic> data) async {
    await _dio.post(Endpoints.adminModules, data: data);
  }

  Future<void> updateModule(int id, Map<String, dynamic> data) async {
    await _dio.patch(Endpoints.adminModule(id), data: data);
  }

  Future<void> deleteModule(int id) async {
    await _dio.delete(Endpoints.adminModule(id));
  }

  // Lessons
  Future<List<dynamic>> getLessons({int? moduleId}) async {
    final params = <String, dynamic>{};
    if (moduleId != null) params['module'] = moduleId;
    final res = await _dio.get(Endpoints.adminLessons, queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<void> createLesson(Map<String, dynamic> data) async {
    await _dio.post(Endpoints.adminLessons, data: data);
  }

  Future<void> updateLesson(int id, Map<String, dynamic> data) async {
    await _dio.patch(Endpoints.adminLesson(id), data: data);
  }

  Future<void> deleteLesson(int id) async {
    await _dio.delete(Endpoints.adminLesson(id));
  }

  // Quizzes
  Future<Map<String, dynamic>?> getQuizForLesson(int lessonId) async {
    try {
      final res = await _dio.get(Endpoints.adminQuizzes, queryParameters: {'lesson': lessonId});
      final list = res.data as List<dynamic>;
      if (list.isEmpty) return null;
      return list.first as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createQuiz(Map<String, dynamic> data) async {
    final res = await _dio.post(Endpoints.adminQuizzes, data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteQuiz(int id) async {
    await _dio.delete(Endpoints.adminQuiz(id));
  }

  // Questions
  Future<List<dynamic>> getQuestions(int quizId) async {
    final res = await _dio.get(Endpoints.adminQuestions, queryParameters: {'quiz': quizId});
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createQuestion(Map<String, dynamic> data) async {
    final res = await _dio.post(Endpoints.adminQuestions, data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteQuestion(int id) async {
    await _dio.delete(Endpoints.adminQuestion(id));
  }

  // Answers
  Future<List<dynamic>> getAnswers(int questionId) async {
    final res = await _dio.get(Endpoints.adminAnswers, queryParameters: {'question': questionId});
    return res.data as List<dynamic>;
  }

  Future<void> createAnswer(Map<String, dynamic> data) async {
    await _dio.post(Endpoints.adminAnswers, data: data);
  }

  Future<void> deleteAnswer(int id) async {
    await _dio.delete(Endpoints.adminAnswer(id));
  }
}
