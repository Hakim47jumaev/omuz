import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/admin_provider.dart';

class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({super.key});

  @override
  State<AdminCoursesScreen> createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<AdminProvider>();
    Future.microtask(() => prov.loadCourses());
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Courses')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCourseDialog(context, prov),
        child: const Icon(Icons.add),
      ),
      body: prov.loading && prov.courses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: prov.courses.length,
              itemBuilder: (context, index) {
                final course = prov.courses[index] as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    title: Text(course['title'] as String),
                    subtitle: Text(course['description'] as String? ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showCourseDialog(context, prov, course: course),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => prov.deleteCourse(course['id'] as int),
                        ),
                      ],
                    ),
                    onTap: () => context.push('/admin/course/${course['id']}/modules'),
                  ),
                );
              },
            ),
    );
  }

  void _showCourseDialog(BuildContext context, AdminProvider prov, {Map<String, dynamic>? course}) {
    final isEdit = course != null;
    final titleC = TextEditingController(text: isEdit ? course['title'] as String : '');
    final descC = TextEditingController(text: isEdit ? (course['description'] as String? ?? '') : '');
    int? selectedCatId = isEdit ? course['category'] as int? : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Course' : 'New Course'),
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
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Category'),
                  initialValue: selectedCatId,
                  items: prov.categories.map((c) {
                    final cat = c as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: cat['id'] as int,
                      child: Text(cat['name'] as String),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedCatId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (selectedCatId == null || titleC.text.isEmpty) return;
                final data = {
                  'title': titleC.text,
                  'description': descC.text,
                  'category': selectedCatId,
                };
                if (isEdit) {
                  await prov.updateCourse(course['id'] as int, data);
                } else {
                  await prov.createCourse(data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}
