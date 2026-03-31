import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/omuz_app_mark.dart';
import '../../core/services/push_service.dart';
import '../auth/providers/auth_provider.dart';
import '../home/presentation/home_screen.dart';
import '../home/presentation/my_courses_screen.dart';
import '../ai/presentation/ai_mentor_screen.dart';
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

    // Staff: shell without Profile tab.
    final screens = isStaff
        ? const [
            HomeScreen(),
            LeaderboardScreen(),
            AdminPanelScreen(),
          ]
        : const [
            HomeScreen(),
            LeaderboardScreen(),
            AiMentorScreen(),
            ProfileScreen(),
            MyCoursesScreen(),
          ];

    final destinations = isStaff
        ? const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home', tooltip: 'Home'),
            NavigationDestination(
              icon: Icon(Icons.leaderboard),
              label: 'Ranks',
              tooltip: 'Leaderboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings),
              label: 'Admin',
              tooltip: 'Admin',
            ),
          ]
        : const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home', tooltip: 'Home'),
            NavigationDestination(
              icon: Icon(Icons.leaderboard),
              label: 'Ranks',
              tooltip: 'Leaderboard',
            ),
            NavigationDestination(icon: Icon(Icons.smart_toy_outlined), label: 'Mentor', tooltip: 'Mentor'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile', tooltip: 'Profile'),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              label: 'Courses',
              tooltip: 'My courses',
            ),
          ];

    final safeIndex = _index.clamp(0, screens.length - 1);

    return Scaffold(
      appBar: safeIndex == 0
          ? AppBar(
              toolbarHeight: 64,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const OmuzMark(size: 44),
                  const SizedBox(width: 14),
                  Text(
                    'Omuz',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                  ),
                ],
              ),
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
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}
