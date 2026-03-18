import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/course_provider.dart';

class CourseDetailScreen extends StatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<CourseProvider>();
    Future.microtask(() => prov.load(widget.courseId));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CourseProvider>();
    final course = prov.course;

    return Scaffold(
      appBar: AppBar(title: Text(course?['title'] ?? 'Course')),
      body: prov.loading || course == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if ((course['description'] as String).isNotEmpty) ...[
                  Text(course['description'] as String,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                ],
                Text('Modules',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...(course['modules'] as List<dynamic>).map((module) {
                  final lessons = module['lessons'] as List<dynamic>;
                  final completedCount = lessons
                      .where((l) =>
                          prov.completedLessonIds.contains(l['id'] as int))
                      .length;
                  final total = lessons.length;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: completedCount == total && total > 0
                            ? Colors.green
                            : Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          completedCount == total && total > 0
                              ? Icons.check
                              : Icons.folder_outlined,
                          color: completedCount == total && total > 0
                              ? Colors.white
                              : Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(module['title'] as String),
                      subtitle: Text('$completedCount / $total lessons completed'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '/course/${widget.courseId}/module/${module['id']}',
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
