import 'package:flutter/material.dart';

import '../data/course_repository.dart';

class CourseProvider extends ChangeNotifier {
  final _repo = CourseRepository();

  Map<String, dynamic>? course;
  Set<int> completedLessonIds = {};
  bool loading = false;

  Future<void> load(int id) async {
    loading = true;
    notifyListeners();
    try {
      course = await _repo.getCourseDetail(id);
      completedLessonIds = await _repo.getCompletedLessonIds(id);
    } catch (_) {}
    loading = false;
    notifyListeners();
  }

  bool isLessonUnlocked(List<dynamic> allLessons, int lessonId) {
    final index = allLessons.indexWhere((l) => l['id'] == lessonId);
    if (index <= 0) return true;
    final prevId = allLessons[index - 1]['id'] as int;
    return completedLessonIds.contains(prevId);
  }
}
