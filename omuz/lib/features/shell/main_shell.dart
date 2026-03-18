import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/providers/auth_provider.dart';
import '../home/presentation/home_screen.dart';
import '../profile/presentation/leaderboard_screen.dart';
import '../profile/presentation/profile_screen.dart';
import '../admin/presentation/admin_panel_screen.dart';

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
    Future.microtask(() => auth.checkStaff());
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = context.watch<AuthProvider>().isStaff;

    final screens = [
      const HomeScreen(),
      const LeaderboardScreen(),
      const ProfileScreen(),
      if (isStaff) const AdminPanelScreen(),
    ];

    final destinations = [
      const NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
      const NavigationDestination(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
      const NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
      if (isStaff)
        const NavigationDestination(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
    ];

    final safeIndex = _index.clamp(0, screens.length - 1);

    return Scaffold(
      appBar: safeIndex == 0
          ? AppBar(title: const Text('OMuz'), centerTitle: true)
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
