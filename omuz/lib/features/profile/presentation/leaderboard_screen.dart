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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isTop3
              ? [Colors.amber, Colors.grey.shade400, Colors.brown.shade300][rank - 1]
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            '$rank',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isTop3 ? Colors.white : null,
            ),
          ),
        ),
        title: Text('${entry['first_name']} ${entry['last_name']}'),
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
