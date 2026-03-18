import 'package:flutter/material.dart';

import '../data/resume_repository.dart';

class ResumeProvider extends ChangeNotifier {
  final _repo = ResumeRepository();

  List<dynamic> resumes = [];
  Map<String, dynamic>? currentResume;
  List<String> skillChoices = [];
  List<Map<String, dynamic>> educationLevelChoices = [];
  bool loading = false;
  bool downloading = false;
  String? lastError;

  Future<void> loadChoices() async {
    try {
      final data = await _repo.getChoices();
      skillChoices = List<String>.from(data['skills'] as List);
      educationLevelChoices = (data['education_levels'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('CHOICES LOAD ERROR: $e');
    }
  }

  Future<void> loadResumes() async {
    loading = true;
    notifyListeners();
    try {
      resumes = await _repo.getResumes();
    } catch (e) {
      debugPrint('RESUMES LOAD ERROR: $e');
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadResume(int id) async {
    loading = true;
    notifyListeners();
    try {
      currentResume = await _repo.getResume(id);
    } catch (e) {
      debugPrint('RESUME LOAD ERROR: $e');
    }
    loading = false;
    notifyListeners();
  }

  Future<int?> createResume(Map<String, dynamic> data) async {
    try {
      final res = await _repo.createResume(data);
      await loadResumes();
      return res['id'] as int;
    } catch (e) {
      debugPrint('CREATE RESUME ERROR: $e');
      lastError = e.toString();
      return null;
    }
  }

  Future<bool> updateResume(int id, Map<String, dynamic> data) async {
    try {
      await _repo.updateResume(id, data);
      await loadResumes();
      return true;
    } catch (e) {
      debugPrint('UPDATE RESUME ERROR: $e');
      lastError = e.toString();
      return false;
    }
  }

  Future<void> deleteResume(int id) async {
    try {
      await _repo.deleteResume(id);
      resumes.removeWhere((r) => r['id'] == id);
      notifyListeners();
    } catch (e) {
      debugPrint('DELETE RESUME ERROR: $e');
    }
  }

  Future<String?> downloadPdf(int id) async {
    downloading = true;
    lastError = null;
    notifyListeners();
    try {
      final path = await _repo.downloadPdf(id);
      return path;
    } catch (e) {
      lastError = e.toString();
      debugPrint('DOWNLOAD PDF ERROR: $e');
      return null;
    } finally {
      downloading = false;
      notifyListeners();
    }
  }
}
