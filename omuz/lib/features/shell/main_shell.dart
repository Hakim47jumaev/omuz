import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/push_service.dart';
import '../auth/providers/auth_provider.dart';
import '../home/presentation/home_screen.dart';
import '../profile/presentation/leaderboard_screen.dart';
import '../profile/presentation/profile_screen.dart';
import '../admin/presentation/admin_panel_screen.dart';
import '../profile/providers/profile_provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final profile = context.read<ProfileProvider>();
    Future.microtask(() => auth.checkStaff());
    Future.microtask(profile.loadNotifications);
    Future.microtask(() async {
      final token = await PushService.getToken();
      if (token != null && token.isNotEmpty) {
        await auth.registerDeviceToken(token, platform: PushService.platform);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = context.watch<AuthProvider>().isStaff;
    final unread = context.watch<ProfileProvider>().unreadNotifications;

    // Админ: отдельный режим без вкладки Profile.
    final screens = isStaff
        ? const [
            HomeScreen(),
            AdminPanelScreen(),
          ]
        : const [
            HomeScreen(),
            LeaderboardScreen(),
            ProfileScreen(),
          ];

    final destinations = isStaff
        ? const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
          ]
        : const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ];

    final safeIndex = _index.clamp(0, screens.length - 1);

    return Scaffold(
      appBar: safeIndex == 0
          ? AppBar(
              title: const Text('OMuz'),
              centerTitle: true,
              actions: [
                IconButton(
                  onPressed: () => context.push('/notifications'),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                ),
              ],
            )
          : null,
      body: IndexedStack(index: safeIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}
