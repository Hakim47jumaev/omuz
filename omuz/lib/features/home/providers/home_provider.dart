import 'package:flutter/material.dart';

import '../data/home_repository.dart';

class HomeProvider extends ChangeNotifier {
  final _repo = HomeRepository();

  List<dynamic> categories = [];
  List<dynamic> courses = [];
  List<dynamic> continueLearning = [];
  bool loading = false;
  int? selectedCategoryId;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      categories = await _repo.getCategories();
      courses = await _repo.getCourses();
      continueLearning = await _repo.getContinueLearning();
    } catch (_) {}
    loading = false;
    notifyListeners();
  }

  Future<void> filterByCategory(int? categoryId) async {
    selectedCategoryId = categoryId;
    loading = true;
    notifyListeners();
    try {
      courses = await _repo.getCourses(categoryId: categoryId);
    } catch (_) {}
    loading = false;
    notifyListeners();
  }
}
