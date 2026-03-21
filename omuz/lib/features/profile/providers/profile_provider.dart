import 'package:flutter/material.dart';

import '../data/profile_repository.dart';

class ProfileProvider extends ChangeNotifier {
  final _repo = ProfileRepository();

  Map<String, dynamic>? profile;
  Map<String, dynamic>? currentNotification;
  Map<String, dynamic>? wallet;
  List<dynamic> transactions = [];
  List<dynamic> notifications = [];
  int unreadNotifications = 0;
  List<dynamic> leaderboard = [];
  bool profileLoading = false;
  bool leaderboardLoading = false;

  Future<void> loadProfile() async {
    profileLoading = true;
    notifyListeners();
    try {
      profile = await _repo.getProfile();
      final user = profile?['user'] as Map<String, dynamic>?;
      final isStaff = user?['is_staff'] == true;
      if (isStaff) {
        wallet = null;
      } else {
        wallet = await _repo.getWallet();
      }
    } catch (e) {
      debugPrint('PROFILE LOAD ERROR: $e');
    }
    profileLoading = false;
    notifyListeners();
  }

  Future<bool> uploadAvatar(String filePath) async {
    try {
      await _repo.uploadAvatar(filePath);
      await loadProfile();
      return true;
    } catch (e) {
      debugPrint('UPLOAD AVATAR ERROR: $e');
      return false;
    }
  }

  Future<void> loadTransactions() async {
    try {
      transactions = await _repo.getTransactions();
      notifyListeners();
    } catch (e) {
      debugPrint('TRANSACTIONS LOAD ERROR: $e');
    }
  }

  Future<void> loadNotifications() async {
    try {
      final data = await _repo.getNotifications();
      notifications = (data['results'] as List<dynamic>? ?? []);
      unreadNotifications = (data['unread_count'] as int?) ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('NOTIFICATIONS LOAD ERROR: $e');
    }
  }

  Future<void> readNotification(int id) async {
    try {
      await _repo.readNotification(id);
      await loadNotifications();
    } catch (e) {
      debugPrint('READ NOTIFICATION ERROR: $e');
    }
  }

  Future<void> readAllNotifications() async {
    try {
      await _repo.readAllNotifications();
      await loadNotifications();
    } catch (e) {
      debugPrint('READ ALL NOTIFICATIONS ERROR: $e');
    }
  }

  Future<void> loadNotificationById(int id) async {
    try {
      currentNotification = await _repo.getNotificationById(id);
      notifyListeners();
    } catch (e) {
      debugPrint('NOTIFICATION DETAIL ERROR: $e');
    }
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
