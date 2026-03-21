import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _dio = ApiClient().dio;
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get(Endpoints.analytics);
      _data = res.data as Map<String, dynamic>;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Failed to load'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildOverview(),
                      const SizedBox(height: 16),
                      _buildProgress(),
                      const SizedBox(height: 16),
                      _buildTopCourses(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOverview() {
    final o = _data!['overview'] as Map<String, dynamic>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statTile('Users', '${o['total_users']}', Icons.people, Colors.blue)),
                Expanded(child: _statTile('Active', '${o['active_users']}', Icons.person, Colors.green)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _statTile('Courses', '${o['total_courses']}', Icons.school, Colors.orange)),
                Expanded(child: _statTile('Lessons', '${o['total_lessons']}', Icons.video_library, Colors.purple)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _statTile('Quizzes', '${o['total_quizzes']}', Icons.quiz, Colors.teal)),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final p = _data!['progress'] as Map<String, dynamic>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Learning Progress', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _progressRow('Videos Watched', p['videos_watched'], Icons.play_circle, Colors.blue),
            _progressRow('Lessons Completed', p['completed_lessons'], Icons.check_circle, Colors.green),
            _progressRow('Quizzes Passed', p['quizzes_passed'], Icons.thumb_up, Colors.teal),
            _progressRow('Quizzes Failed', p['quizzes_failed'], Icons.thumb_down, Colors.red),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Average Quiz Score'),
                Chip(
                  label: Text('${p['avg_quiz_score']}%',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCourses() {
    final top = _data!['top_courses'] as List<dynamic>;
    if (top.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Courses', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...top.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value as Map<String, dynamic>;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: i < 3
                      ? [Colors.amber, Colors.grey.shade400, Colors.brown.shade300][i]
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text('${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: i < 3 ? Colors.white : null,
                      )),
                ),
                title: Text(c['title'] as String),
                trailing: Text('${c['completions']} completions',
                    style: Theme.of(context).textTheme.bodySmall),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _progressRow(String label, dynamic value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
