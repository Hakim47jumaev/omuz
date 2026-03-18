import 'package:flutter/material.dart';

import '../data/lesson_repository.dart';

class LessonProvider extends ChangeNotifier {
  final _repo = LessonRepository();

  Map<String, dynamic>? lesson;
  bool loading = false;

  bool videoWatched = false;
  bool quizPassed = false;
  int quizScore = 0;
  bool completed = false;
  bool hasQuiz = false;

  Future<void> load(int id) async {
    loading = true;
    videoWatched = false;
    quizPassed = false;
    quizScore = 0;
    completed = false;
    hasQuiz = false;
    notifyListeners();
    try {
      lesson = await _repo.getLesson(id);
      final status = await _repo.getLessonStatus(id);
      videoWatched = status['video_watched'] as bool;
      quizPassed = status['quiz_passed'] as bool;
      quizScore = status['quiz_score'] as int;
      completed = status['is_completed'] as bool;
      hasQuiz = status['has_quiz'] as bool? ?? (lesson?['has_quiz'] == true);
    } catch (_) {}
    loading = false;
    notifyListeners();
  }

  Future<void> markVideoWatched(int lessonId) async {
    if (videoWatched) return;
    try {
      final res = await _repo.markVideoWatched(lessonId);
      videoWatched = res['video_watched'] as bool;
      quizPassed = res['quiz_passed'] as bool;
      completed = res['is_completed'] as bool;
      notifyListeners();
    } catch (_) {}
  }

  void updateAfterQuiz({required bool passed, required int score, required bool lessonCompleted}) {
    if (passed) {
      quizPassed = true;
      quizScore = score;
    }
    if (lessonCompleted) {
      completed = true;
    }
    notifyListeners();
  }
}
