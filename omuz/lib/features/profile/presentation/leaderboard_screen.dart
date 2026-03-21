import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<ProfileProvider>();
    Future.microtask(() => prov.loadLeaderboard());
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: prov.leaderboardLoading && prov.leaderboard.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : prov.leaderboard.isEmpty
              ? const Center(child: Text('No students yet'))
              : RefreshIndicator(
                  onRefresh: () => prov.loadLeaderboard(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: prov.leaderboard.length,
                    itemBuilder: (context, index) {
                      final entry = prov.leaderboard[index] as Map<String, dynamic>;
                      return _buildEntry(entry, index);
                    },
                  ),
                ),
    );
  }

  Widget _buildEntry(Map<String, dynamic> entry, int index) {
    final rank = entry['rank'] as int;
    final isTop3 = rank <= 3;
    final firstName = (entry['first_name'] as String? ?? '').trim();
    final lastName = (entry['last_name'] as String? ?? '').trim();
    final fullName = [firstName, lastName].where((e) => e.isNotEmpty).join(' ');
    final initialsSource = firstName.isNotEmpty ? firstName : (lastName.isNotEmpty ? lastName : '?');
    final avatarUrl = (entry['avatar_url'] as String?)?.trim() ?? '';
    final hasAvatar = avatarUrl.isNotEmpty;
    final rankColor = isTop3
        ? [Colors.amber, Colors.grey.shade500, Colors.brown.shade400][rank - 1]
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
              child: hasAvatar
                  ? null
                  : Text(
                      initialsSource[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rankColor,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isTop3 ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(fullName.isEmpty ? 'Студент' : fullName),
        subtitle: Text('Level ${entry['level']}'),
        trailing: Text(
          '${entry['total_xp']} XP',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
