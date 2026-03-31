import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/omuz_ui.dart';
import '../../auth/providers/auth_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CourseProvider>();
    final isStaff = context.watch<AuthProvider>().isStaff;
    final course = prov.course;
    final sub = prov.subscription;
    final isPaidCourse = (course?['is_free'] == false);
    final noAccess =
        !isStaff && isPaidCourse && (sub?['is_active'] != true);
    final modules = (course?['modules'] as List<dynamic>?) ?? const [];

    final cs = Theme.of(context).colorScheme;

    if (prov.loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Module')),
        body: OmuzPage.background(
          context: context,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (noAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Module')),
        body: OmuzPage.background(
          context: context,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Modules and lessons are locked.\nPurchase the course to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ),
      );
    }

    if (modules.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Course modules')),
        body: OmuzPage.background(
          context: context,
          child: Center(
            child: Text('No modules yet', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Course modules')),
      body: OmuzPage.background(
        context: context,
        child: ListView.builder(
          padding: OmuzPage.padding,
          itemCount: modules.length,
          itemBuilder: (context, moduleIndex) {
          final module = modules[moduleIndex] as Map<String, dynamic>;
          final lessons = (module['lessons'] as List<dynamic>?) ?? const [];
          final moduleUnlocked =
              isStaff || _isModuleUnlocked(modules, moduleIndex, prov);
          final completedCount = lessons
              .where((l) => prov.completedLessonIds.contains(l['id'] as int))
              .length;
          final totalCount = lessons.length;
          final completionPercent = totalCount == 0
              ? 100
              : ((completedCount / totalCount) * 100).round();

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              initiallyExpanded: module['id'] == widget.moduleId && moduleUnlocked,
              enabled: moduleUnlocked,
              leading: Icon(
                moduleUnlocked ? Icons.menu_book_outlined : Icons.lock,
                color: moduleUnlocked ? null : cs.onSurfaceVariant,
              ),
              title: Text(
                module['title'] as String,
                style: TextStyle(color: moduleUnlocked ? null : cs.onSurfaceVariant),
              ),
              subtitle: Text('$completedCount/$totalCount lessons · $completionPercent%'),
              children: [
                if (!moduleUnlocked)
                  const ListTile(
                    title: Text(
                      'The next module unlocks after you complete 90% of the previous one.',
                    ),
                  ),
                if (moduleUnlocked && lessons.isEmpty)
                  const ListTile(title: Text('No lessons yet')),
                if (moduleUnlocked)
                  ...lessons.asMap().entries.map((entry) {
                    final lessonIndex = entry.key;
                    final lesson = entry.value as Map<String, dynamic>;
                    final lessonId = lesson['id'] as int;
                    final isCompleted = prov.completedLessonIds.contains(lessonId);
                    final lessonUnlocked =
                        isStaff || _isLessonUnlocked(lessons, lessonIndex, prov);

                    return ListTile(
                      leading: Icon(
                        isCompleted
                            ? Icons.check_circle
                            : lessonUnlocked
                                ? Icons.play_circle_outline
                                : Icons.lock,
                        color: isCompleted
                            ? AppTheme.success
                            : lessonUnlocked
                                ? null
                                : cs.onSurfaceVariant,
                      ),
                      title: Text(
                        lesson['title'] as String,
                        style: TextStyle(color: lessonUnlocked ? null : cs.onSurfaceVariant),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: lessonUnlocked ? null : cs.onSurfaceVariant,
                      ),
                      onTap: lessonUnlocked
                          ? () async {
                              await context.push('/lesson/$lessonId');
                              if (mounted) prov.load(widget.courseId);
                            }
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Complete the previous lesson first'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                    );
                  }),
              ],
            ),
          );
        },
        ),
      ),
    );
  }

  bool _isLessonUnlocked(List<dynamic> lessons, int index, CourseProvider prov) {
    if (index == 0) return true;
    final prevId = lessons[index - 1]['id'] as int;
    return prov.completedLessonIds.contains(prevId);
  }

  bool _isModuleUnlocked(
    List<dynamic> modules,
    int moduleIndex,
    CourseProvider prov,
  ) {
    if (moduleIndex == 0) return true;
    final prevModule = modules[moduleIndex - 1] as Map<String, dynamic>;
    final prevLessons = (prevModule['lessons'] as List<dynamic>?) ?? const [];
    if (prevLessons.isEmpty) return true;
    final completed = prevLessons
        .where((l) => prov.completedLessonIds.contains(l['id'] as int))
        .length;
    final ratio = completed / prevLessons.length;
    return ratio >= 0.9;
  }
}
