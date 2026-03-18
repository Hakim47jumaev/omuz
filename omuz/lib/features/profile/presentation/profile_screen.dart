import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<ProfileProvider>();
    Future.microtask(() => prov.loadProfile());
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProfileProvider>();
    final profile = prov.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: prov.profileLoading || profile == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => prov.loadProfile(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildUserCard(profile),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/resume'),
                    icon: const Icon(Icons.description),
                    label: const Text('My Resume'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildXPCard(profile['xp'] as Map<String, dynamic>),
                  const SizedBox(height: 16),
                  _buildBadges(profile['badges'] as List<dynamic>),
                  const SizedBox(height: 16),
                  _buildHistory(profile['xp_history'] as List<dynamic>),
                ],
              ),
            ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> profile) {
    final user = profile['user'] as Map<String, dynamic>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(
                (user['first_name'] as String? ?? '?')[0].toUpperCase(),
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user['first_name']} ${user['last_name']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  user['phone'] as String,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXPCard(Map<String, dynamic> xp) {
    final totalXp = xp['total_xp'] as int;
    final level = xp['level'] as int;
    final progressInLevel = (totalXp % 100) / 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _xpStat('Level', '$level', Icons.star, Colors.amber),
                _xpStat('Total XP', '$totalXp', Icons.bolt, Colors.orange),
                _xpStat(
                  'Next Level',
                  '${100 - (totalXp % 100)} XP',
                  Icons.arrow_upward,
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progressInLevel,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _xpStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildBadges(List<dynamic> badges) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Badges', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (badges.isEmpty)
          const Text('No badges yet. Complete lessons to earn them!')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges.map((b) {
              return Chip(
                avatar: const Icon(Icons.emoji_events, size: 18),
                label: Text(b['label'] as String),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildHistory(List<dynamic> history) {
    if (history.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('XP History', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...history.map((h) => ListTile(
              dense: true,
              leading: const Icon(Icons.add_circle, color: Colors.green, size: 20),
              title: Text(h['reason'] as String),
              trailing: Text('+${h['amount']} XP',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
      ],
    );
  }
}
