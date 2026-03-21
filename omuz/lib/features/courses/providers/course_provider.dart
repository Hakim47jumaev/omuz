import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/course_repository.dart';

class CourseProvider extends ChangeNotifier {
  final _repo = CourseRepository();

  Map<String, dynamic>? course;
  Map<String, dynamic>? subscription;
  Set<int> completedLessonIds = {};
  bool loading = false;
  String? lastError;

  bool get hasAccess {
    if (subscription == null) return false;
    return subscription!['is_active'] == true;
  }

  Future<void> load(int id) async {
    loading = true;
    notifyListeners();
    try {
      course = await _repo.getCourseDetail(id);
      subscription = await _repo.getSubscription(id);
      completedLessonIds = await _repo.getCompletedLessonIds(id);
    } catch (e) {
      debugPrint('COURSE LOAD ERROR: $e');
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> purchase(int courseId) async {
    try {
      await _repo.purchaseCourse(courseId);
      lastError = null;
      subscription = await _repo.getSubscription(courseId);
      notifyListeners();
      return true;
    } catch (e) {
      lastError = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> renew(int courseId, int days) async {
    try {
      await _repo.renewCourse(courseId, days);
      lastError = null;
      subscription = await _repo.getSubscription(courseId);
      notifyListeners();
      return true;
    } catch (e) {
      lastError = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['string'] != null) {
            return first['string'] as String;
          }
        }
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Превышено время ожидания. Проверьте интернет и сервер.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Нет соединения с сервером. Проверьте, что бэкенд запущен и adb reverse / Wi‑Fi настроены.';
      }
    }
    final str = e.toString();
    final match = RegExp(r'"detail":"([^"]+)"').firstMatch(str);
    if (match != null) return match.group(1)!;
    return str;
  }

  bool isLessonUnlocked(List<dynamic> allLessons, int lessonId) {
    final index = allLessons.indexWhere((l) => l['id'] == lessonId);
    if (index <= 0) return true;
    final prevId = allLessons[index - 1]['id'] as int;
    return completedLessonIds.contains(prevId);
  }
}
