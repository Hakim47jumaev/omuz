import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/course_provider.dart';

class ModuleDetailScreen extends StatefulWidget {
  final int courseId;
  final int moduleId;
  const ModuleDetailScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
  });

  @override
  State<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<CourseProvider>();
    if (prov.course == null) {
      Future.microtask(() => prov.load(widget.courseId));
    }
  }

  Map<String, dynamic>? _findModule(CourseProvider prov) {
    if (prov.course == null) return null;
    final modules = prov.course!['modules'] as List<dynamic>;
    for (final m in modules) {
      if (m['id'] == widget.moduleId) return m as Map<String, dynamic>;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CourseProvider>();
    final module = _findModule(prov);

    if (prov.loading || module == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Module')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final lessons = module['lessons'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(title: Text(module['title'] as String)),
      body: lessons.isEmpty
          ? const Center(child: Text('No lessons yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: lessons.length,
              itemBuilder: (context, index) {
                final lesson = lessons[index] as Map<String, dynamic>;
                final lessonId = lesson['id'] as int;
                final isCompleted = prov.completedLessonIds.contains(lessonId);
                final isUnlocked = _isUnlocked(lessons, index, prov);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      isCompleted
                          ? Icons.check_circle
                          : isUnlocked
                              ? Icons.play_circle_outline
                              : Icons.lock,
                      color: isCompleted
                          ? Colors.green
                          : isUnlocked
                              ? null
                              : Colors.grey,
                    ),
                    title: Text(
                      lesson['title'] as String,
                      style: TextStyle(color: isUnlocked ? null : Colors.grey),
                    ),
                    trailing: Icon(Icons.chevron_right,
                        color: isUnlocked ? null : Colors.grey),
                    onTap: isUnlocked
                        ? () async {
                            await context.push('/lesson/$lessonId');
                            if (mounted) prov.load(widget.courseId);
                          }
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Complete the previous lesson first'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                  ),
                );
              },
            ),
    );
  }

  bool _isUnlocked(List<dynamic> lessons, int index, CourseProvider prov) {
    if (index == 0) return true;
    final prevId = lessons[index - 1]['id'] as int;
    return prov.completedLessonIds.contains(prevId);
  }
}
