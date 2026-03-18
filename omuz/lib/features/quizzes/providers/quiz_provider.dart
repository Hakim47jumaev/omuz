import 'package:flutter/material.dart';

import '../data/quiz_repository.dart';

class QuizProvider extends ChangeNotifier {
  final _repo = QuizRepository();

  Map<String, dynamic>? quiz;
  bool loading = false;

  // question_id -> selected answer_id
  final Map<String, int> selectedAnswers = {};

  Map<String, dynamic>? result;
  bool submitting = false;

  Future<void> load(int lessonId) async {
    loading = true;
    result = null;
    selectedAnswers.clear();
    notifyListeners();
    try {
      quiz = await _repo.getQuizByLesson(lessonId);
    } catch (_) {}
    loading = false;
    notifyListeners();
  }

  void selectAnswer(String questionId, int answerId) {
    selectedAnswers[questionId] = answerId;
    notifyListeners();
  }

  Future<void> submit() async {
    if (quiz == null) return;
    submitting = true;
    notifyListeners();
    try {
      result = await _repo.submitQuiz(quiz!['id'] as int, selectedAnswers);
    } catch (_) {}
    submitting = false;
    notifyListeners();
  }
}
