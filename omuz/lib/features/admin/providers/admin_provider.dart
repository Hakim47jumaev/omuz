import 'package:flutter/material.dart';

import '../data/admin_repository.dart';

class AdminProvider extends ChangeNotifier {
  final _repo = AdminRepository();

  List<dynamic> categories = [];
  List<dynamic> courses = [];
  List<dynamic> modules = [];
  List<dynamic> lessons = [];
  bool loading = false;
  String? error;

  Future<void> loadCategories() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      categories = await _repo.getCategories();
    } catch (e) {
      error = '$e';
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> createCategory(String name, String icon) async {
    try {
      await _repo.createCategory({'name': name, 'icon': icon});
      await loadCategories();
      return true;
    } catch (e) {
      error = '$e';
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteCategory(int id) async {
    await _repo.deleteCategory(id);
    await loadCategories();
  }

  Future<void> loadCourses() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      courses = await _repo.getCourses();
      if (categories.isEmpty) categories = await _repo.getCategories();
    } catch (e) {
      error = '$e';
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> createCourse(Map<String, dynamic> data) async {
    try {
      await _repo.createCourse(data);
      await loadCourses();
      return true;
    } catch (e) {
      error = '$e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCourse(int id, Map<String, dynamic> data) async {
    try {
      await _repo.updateCourse(id, data);
      await loadCourses();
      return true;
    } catch (e) {
      error = '$e';
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteCourse(int id) async {
    await _repo.deleteCourse(id);
    await loadCourses();
  }

  Future<void> loadModules(int courseId) async {
    loading = true;
    notifyListeners();
    try {
      modules = await _repo.getModules(courseId: courseId);
    } catch (e) {
      error = '$e';
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> createModule(Map<String, dynamic> data) async {
    try {
      await _repo.createModule(data);
      return true;
    } catch (e) {
      error = '$e';
      notifyListeners();
      return false;
    }
  }

  Future<void> updateModule(int id, Map<String, dynamic> data) async {
    await _repo.updateModule(id, data);
  }

  Future<void> reorderModules(int oldIndex, int newIndex, int courseId) async {
    if (newIndex > oldIndex) newIndex--;
    final item = modules.removeAt(oldIndex);
    modules.insert(newIndex, item);
    notifyListeners();
    for (int i = 0; i < modules.length; i++) {
      final mod = modules[i] as Map<String, dynamic>;
      await _repo.updateModule(mod['id'] as int, {'order': i});
    }
  }

  Future<void> deleteModule(int id, int courseId) async {
    await _repo.deleteModule(id);
    await loadModules(courseId);
  }

  Future<void> loadLessons(int moduleId) async {
    loading = true;
    notifyListeners();
    try {
      lessons = await _repo.getLessons(moduleId: moduleId);
    } catch (e) {
      error = '$e';
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> createLesson(Map<String, dynamic> data) async {
    try {
      await _repo.createLesson(data);
      return true;
    } catch (e) {
      error = '$e';
      notifyListeners();
      return false;
    }
  }

  Future<void> updateLesson(int id, Map<String, dynamic> data, int moduleId) async {
    await _repo.updateLesson(id, data);
    await loadLessons(moduleId);
  }

  Future<void> deleteLesson(int id, int moduleId) async {
    await _repo.deleteLesson(id);
    await loadLessons(moduleId);
  }
}
