import 'package:flutter/material.dart';

import '../data/profile_repository.dart';

class ProfileProvider extends ChangeNotifier {
  final _repo = ProfileRepository();

  Map<String, dynamic>? profile;
  List<dynamic> leaderboard = [];
  bool profileLoading = false;
  bool leaderboardLoading = false;

  Future<void> loadProfile() async {
    profileLoading = true;
    notifyListeners();
    try {
      profile = await _repo.getProfile();
    } catch (e) {
      debugPrint('PROFILE LOAD ERROR: $e');
    }
    profileLoading = false;
    notifyListeners();
  }

  Future<void> loadLeaderboard() async {
    leaderboardLoading = true;
    notifyListeners();
    try {
      leaderboard = await _repo.getLeaderboard();
    } catch (e) {
      debugPrint('LEADERBOARD LOAD ERROR: $e');
    }
    leaderboardLoading = false;
    notifyListeners();
  }
}
