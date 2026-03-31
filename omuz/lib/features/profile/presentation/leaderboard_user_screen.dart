import 'package:flutter/material.dart';

import '../../../core/api/api_error_message.dart';
import '../data/profile_repository.dart';

class LeaderboardUserScreen extends StatefulWidget {
  const LeaderboardUserScreen({super.key, required this.userId});

  final int userId;

  @override
  State<LeaderboardUserScreen> createState() => _LeaderboardUserScreenState();
}

class _LeaderboardUserScreenState extends State<LeaderboardUserScreen> {
  final _repo = ProfileRepository();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await _repo.getLeaderboardUser(widget.userId);
      if (mounted) {
        setState(() {
          _data = m;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  static String _shortDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Learner profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _data == null
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No data')),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            _buildHeader(_data!, cs, tt),
                            const SizedBox(height: 20),
                            Text(
                              'How they earned XP',
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._buildHistory(_data!, cs, tt),
                          ],
                        ),
                ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> data, ColorScheme cs, TextTheme tt) {
    final user = data['user'] as Map<String, dynamic>?;
    final fn = (user?['first_name'] as String? ?? '').trim();
    final ln = (user?['last_name'] as String? ?? '').trim();
    final name = [fn, ln].where((e) => e.isNotEmpty).join(' ');
    final avatarUrl = (user?['avatar_url'] as String?)?.trim() ?? '';
    final totalXp = data['total_xp'];
    final level = data['level'];
    final curStreak = data['current_streak'];
    final bestStreak = data['best_streak'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Learner' : name,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$totalXp XP · Level $level',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (curStreak != null || bestStreak != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Streak: $curStreak · Best: $bestStreak',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHistory(Map<String, dynamic> data, ColorScheme cs, TextTheme tt) {
    final raw = data['xp_history'] as List<dynamic>? ?? [];
    if (raw.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No XP transactions yet',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ];
    }
    return raw.map<Widget>((e) {
      final m = e as Map<String, dynamic>;
      final amount = m['amount'];
      final reason = (m['reason'] as String?) ?? '';
      final when = _shortDate(m['created_at'] as String?);
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(
            reason.isEmpty ? 'XP' : reason,
            style: tt.bodyMedium,
          ),
          subtitle: when.isNotEmpty ? Text(when, style: tt.bodySmall) : null,
          trailing: Text(
            '+$amount',
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
        ),
      );
    }).toList();
  }
}
