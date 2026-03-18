import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/admin_provider.dart';

class AdminLessonsScreen extends StatefulWidget {
  final int moduleId;
  const AdminLessonsScreen({super.key, required this.moduleId});

  @override
  State<AdminLessonsScreen> createState() => _AdminLessonsScreenState();
}

class _AdminLessonsScreenState extends State<AdminLessonsScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<AdminProvider>();
    Future.microtask(() => prov.loadLessons(widget.moduleId));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Lessons')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLessonDialog(context, prov),
        child: const Icon(Icons.add),
      ),
      body: prov.loading && prov.lessons.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : prov.lessons.isEmpty
              ? const Center(child: Text('No lessons yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: prov.lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = prov.lessons[index] as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(lesson['title'] as String),
                        subtitle: Text(
                          lesson['video_url'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () =>
                                  _showLessonDialog(context, prov, lesson: lesson),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () =>
                                  prov.deleteLesson(lesson['id'] as int, widget.moduleId),
                            ),
                          ],
                        ),
                        onTap: () => context.push(
                          '/admin/lesson/${lesson['id']}/quiz',
                          extra: lesson['title'] as String,
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showLessonDialog(BuildContext context, AdminProvider prov,
      {Map<String, dynamic>? lesson}) {
    final isEdit = lesson != null;
    final titleC = TextEditingController(text: isEdit ? lesson['title'] as String : '');
    final descC = TextEditingController(
        text: isEdit ? (lesson['description'] as String? ?? '') : '');
    final videoC = TextEditingController(
        text: isEdit ? (lesson['video_url'] as String? ?? '') : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Lesson' : 'New Lesson'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleC,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descC,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: videoC,
                decoration: const InputDecoration(labelText: 'YouTube URL'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (titleC.text.isEmpty || videoC.text.isEmpty) return;
              if (isEdit) {
                await prov.updateLesson(
                  lesson['id'] as int,
                  {
                    'title': titleC.text,
                    'description': descC.text,
                    'video_url': videoC.text,
                  },
                  widget.moduleId,
                );
              } else {
                await prov.createLesson({
                  'module': widget.moduleId,
                  'title': titleC.text,
                  'description': descC.text,
                  'video_url': videoC.text,
                  'order': prov.lessons.length,
                });
                await prov.loadLessons(widget.moduleId);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isEdit ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }
}
