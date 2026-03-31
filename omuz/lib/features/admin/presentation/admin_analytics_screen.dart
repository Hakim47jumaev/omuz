import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/omuz_ui.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _dio = ApiClient().dio;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _period = '1m';
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get(
        Endpoints.analytics,
        queryParameters: _buildQuery(),
      );
      _data = res.data as Map<String, dynamic>;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> _buildQuery() {
    final q = <String, dynamic>{'period': _period};
    if (_period == 'custom' && _customStart != null && _customEnd != null) {
      q['start_date'] = _fmtDate(_customStart!);
      q['end_date'] = _fmtDate(_customEnd!);
    }
    return q;
  }

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _pickCustomDates() async {
    final now = DateTime.now();
    final start = await showDatePicker(
      context: context,
      initialDate: _customStart ?? now.subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (start == null || !mounted) return;
    final end = await showDatePicker(
      context: context,
      initialDate: _customEnd ?? now,
      firstDate: start,
      lastDate: now,
    );
    if (end == null) return;
    setState(() {
      _customStart = start;
      _customEnd = end;
      _period = 'custom';
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _loading
          ? OmuzPage.background(
              context: context,
              child: const Center(child: CircularProgressIndicator()),
            )
          : _data == null
              ? OmuzPage.background(
                  context: context,
                  child: Center(
                    child: Text(
                      'Failed to load',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : OmuzPage.background(
                  context: context,
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: OmuzPage.padding,
                      children: [
                        _buildFilters(),
                        const SizedBox(height: 12),
                        _buildOverview(),
                        const SizedBox(height: 16),
                        _buildProgress(),
                        const SizedBox(height: 16),
                        _buildTopCourses(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Period'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _periodChip('10d', '10 days'),
                _periodChip('1m', 'Month'),
                _periodChip('6m', '6 months'),
                _periodChip('all', 'All time'),
                OutlinedButton.icon(
                  onPressed: _pickCustomDates,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _customStart != null && _customEnd != null
                        ? '${_fmtDate(_customStart!)} - ${_fmtDate(_customEnd!)}'
                        : 'Custom range',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(String code, String label) {
    final selected = _period == code;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) async {
        setState(() => _period = code);
        await _load();
      },
    );
  }

  Widget _buildOverview() {
    final cs = Theme.of(context).colorScheme;
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
                Expanded(
                    child: _statTile('Users', '${o['total_users']}', Icons.people, cs.primary)),
                Expanded(
                    child: _statTile(
                        'Active', '${o['active_users']}', Icons.person, AppTheme.success)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _statTile(
                        'Courses', '${o['total_courses']}', Icons.school, cs.secondary)),
                Expanded(
                    child: _statTile('Lessons', '${o['total_lessons']}', Icons.video_library,
                        cs.tertiary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _statTile(
                        'Quizzes', '${o['total_quizzes']}', Icons.quiz, cs.primaryContainer)),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final cs = Theme.of(context).colorScheme;
    final p = _data!['progress'] as Map<String, dynamic>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Learning Progress', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _progressRow('Videos Watched', p['videos_watched'], Icons.play_circle, cs.primary),
            _progressRow('Lessons Completed', p['completed_lessons'], Icons.check_circle, AppTheme.success),
            _progressRow('Quizzes Passed', p['quizzes_passed'], Icons.thumb_up, cs.secondary),
            _progressRow('Quizzes Failed', p['quizzes_failed'], Icons.thumb_down, AppTheme.danger),
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
    final cs = Theme.of(context).colorScheme;
    final medals = [cs.primary, cs.secondary, cs.outline];
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
                  backgroundColor:
                      i < 3 ? medals[i] : cs.surfaceContainerHighest,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: i < 3
                          ? (medals[i] == cs.outline
                              ? cs.onSurface
                              : cs.onPrimary)
                          : null,
                    ),
                  ),
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
