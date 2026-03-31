import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../data/quiz_repository.dart';

class QuizProvider extends ChangeNotifier {
  final _repo = QuizRepository();

  Map<String, dynamic>? quiz;
  bool loading = false;

  // question_id -> selected answer_id
  final Map<String, int> selectedAnswers = {};

  Map<String, dynamic>? result;
  bool submitting = false;
  String? lastError;
  bool readingCheckpointConfirmed = false;

  Future<void> load(int lessonId) async {
    loading = true;
    result = null;
    lastError = null;
    readingCheckpointConfirmed = false;
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

  void setReadingCheckpoint(bool value) {
    readingCheckpointConfirmed = value;
    notifyListeners();
  }

  Future<bool> submit() async {
    if (quiz == null) return false;
    submitting = true;
    lastError = null;
    notifyListeners();
    try {
      result = await _repo.submitQuiz(
        quiz!['id'] as int,
        selectedAnswers,
        confirmReadingCheckpoint: readingCheckpointConfirmed,
      );
      submitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['detail'] is String) {
          lastError = data['detail'] as String;
        } else {
          lastError = 'Quiz submit failed';
        }
      } else {
        lastError = e.toString();
      }
    }
    submitting = false;
    notifyListeners();
    return false;
  }
}
