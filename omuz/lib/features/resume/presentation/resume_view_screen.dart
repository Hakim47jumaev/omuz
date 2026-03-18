import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../providers/resume_provider.dart';

class ResumeViewScreen extends StatefulWidget {
  final int resumeId;
  const ResumeViewScreen({super.key, required this.resumeId});

  @override
  State<ResumeViewScreen> createState() => _ResumeViewScreenState();
}

class _ResumeViewScreenState extends State<ResumeViewScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<ResumeProvider>();
    Future.microtask(() => prov.loadResume(widget.resumeId));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ResumeProvider>();
    final cs = Theme.of(context).colorScheme;
    final data = prov.currentResume;

    return Scaffold(
      appBar: AppBar(title: const Text('Resume')),
      body: prov.loading || data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(data, cs),
                const SizedBox(height: 16),
                if ((data['education_level'] as String?)?.isNotEmpty == true)
                  _section('Education Level', Icons.school, [
                    Text(_educationLabel(data['education_level'] as String)),
                  ], cs),
                if ((data['education'] as List?)?.isNotEmpty == true)
                  _section('Education', Icons.account_balance, [
                    ...(data['education'] as List).map((e) => _eduTile(e, cs)),
                  ], cs),
                if ((data['skills'] as List?)?.isNotEmpty == true)
                  _section('Skills', Icons.psychology, [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (data['skills'] as List)
                          .map((s) => Chip(
                                label: Text(s as String),
                                backgroundColor: cs.secondaryContainer,
                                side: BorderSide.none,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ], cs),
                if ((data['work_experience'] as List?)?.isNotEmpty == true)
                  _section('Work Experience', Icons.work, [
                    ...(data['work_experience'] as List).map((w) => _workTile(w, cs)),
                  ], cs),
                if ((data['completed_courses'] as List?)?.isNotEmpty == true)
                  _section('Completed Courses', Icons.emoji_events, [
                    ...(data['completed_courses'] as List).map(
                      (c) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.check_circle, color: cs.primary, size: 20),
                        title: Text(c as String),
                      ),
                    ),
                  ], cs),
                if ((data['achievements'] as List?)?.isNotEmpty == true)
                  _section('Achievements', Icons.star, [
                    ...(data['achievements'] as List).map(
                      (a) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.military_tech, color: Colors.amber, size: 20),
                        title: Text(a as String),
                      ),
                    ),
                  ], cs),
                const SizedBox(height: 16),
                _downloadBtn(prov, cs),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _header(Map<String, dynamic> data, ColorScheme cs) {
    final name = '${data['first_name']} ${data['last_name']}'.trim();
    final patronymic = data['patronymic'] as String? ?? '';
    final email = data['email'] as String? ?? '';
    final job = data['current_job'] as String? ?? '';
    final gender = data['gender'] as String? ?? '';
    final bday = data['birthday'] as String? ?? '';

    return Card(
      elevation: 0,
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: cs.primary,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 26, color: cs.onPrimary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patronymic.isNotEmpty ? '$name $patronymic' : name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
                      ),
                      if (job.isNotEmpty)
                        Text(job, style: TextStyle(color: cs.onPrimaryContainer.withAlpha(200), fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            if (email.isNotEmpty || gender.isNotEmpty || bday.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (email.isNotEmpty)
                    _infoChip(Icons.email, email, cs),
                  if (gender.isNotEmpty)
                    _infoChip(Icons.person, gender == 'male' ? 'Male' : 'Female', cs),
                  if (bday.isNotEmpty)
                    _infoChip(Icons.cake, bday, cs),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: cs.onPrimaryContainer.withAlpha(180)),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer.withAlpha(200))),
      ],
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: cs.primary, size: 22),
                const SizedBox(width: 8),
                Text(title,
                    style: Theme.of(context)
                        .textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _eduTile(dynamic edu, ColorScheme cs) {
    final e = edu as Map<String, dynamic>;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e['institution'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            [e['faculty'], e['specialization'], e['graduation_year']]
                .where((v) => v != null && v.toString().isNotEmpty)
                .join(' | '),
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _workTile(dynamic work, ColorScheme cs) {
    final w = work as Map<String, dynamic>;
    final end = (w['end_date'] as String?)?.isNotEmpty == true ? w['end_date'] : 'Present';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${w['position']}', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${w['company']}', style: TextStyle(color: cs.onSurfaceVariant)),
          Text('${w['start_date']} - $end',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  String _educationLabel(String value) {
    const map = {
      'higher': 'Higher education',
      'secondary_special': 'Secondary special',
      'secondary': 'General secondary',
      'phd': 'PhD',
      'doctorate': 'Doctorate',
      'bachelor': 'Bachelor',
      'master': 'Master',
    };
    return map[value] ?? value;
  }

  Widget _downloadBtn(ResumeProvider prov, ColorScheme cs) {
    return FilledButton.icon(
      onPressed: prov.downloading
          ? null
          : () async {
              final path = await prov.downloadPdf(widget.resumeId);
              if (!mounted) return;
              if (path != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF saved, opening...')),
                );
                await OpenFilex.open(path);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: ${prov.lastError ?? "unknown"}')),
                );
              }
            },
      icon: prov.downloading
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.download),
      label: Text(prov.downloading ? 'Generating...' : 'Download PDF'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
