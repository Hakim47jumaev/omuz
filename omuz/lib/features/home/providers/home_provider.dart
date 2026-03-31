import 'package:flutter/material.dart';

import '../../../core/api/api_error_message.dart';
import '../data/home_repository.dart';

class HomeProvider extends ChangeNotifier {
  final _repo = HomeRepository();

  List<dynamic> categories = [];
  List<dynamic> courses = [];
  List<dynamic> continueLearning = [];
  List<dynamic> recommendations = [];
  List<dynamic> popularCourses = [];
  List<dynamic> myCourses = [];
  Map<String, dynamic> promotions = {
    'is_active': false,
    'name': null,
    'percent': 0,
    'ends_at': null,
    'courses': <dynamic>[],
  };
  bool loading = false;
  int? selectedCategoryId;

  /// Load error from backend (network, URL, 5xx). Empty home often means no connectivity.
  String? loadError;

  Future<void> load() async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      categories = await _repo.getCategories();
      Map<String, dynamic> feed = {};
      try {
        feed = await _repo.getHomeFeed();
      } catch (e) {
        debugPrint('HOME FEED ERROR: $e');
      }
      popularCourses = (feed['popular'] as List<dynamic>?) ?? [];
      recommendations = (feed['for_you'] as List<dynamic>?) ?? [];
      continueLearning = (feed['continue'] as List<dynamic>?) ?? [];
      myCourses = (feed['my_courses'] as List<dynamic>?) ?? [];
      courses = await _repo.getCourses();
      promotions = await _repo.getPromotions();
    } catch (e) {
      loadError = apiErrorMessage(e);
      debugPrint('HOME LOAD ERROR: $e');
    }
    loading = false;
    notifyListeners();
  }

  Future<void> filterByCategory(int? categoryId) async {
    selectedCategoryId = categoryId;
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      courses = await _repo.getCourses(categoryId: categoryId);
    } catch (e) {
      loadError = apiErrorMessage(e);
      debugPrint('HOME FILTER ERROR: $e');
    }
    loading = false;
    notifyListeners();
  }
}
