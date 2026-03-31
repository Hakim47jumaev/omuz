import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/omuz_ui.dart';
import '../providers/home_provider.dart';

class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  @override
  void initState() {
    super.initState();
    final home = context.read<HomeProvider>();
    Future.microtask(() async {
      if (home.myCourses.isEmpty && !home.loading) {
        await home.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My courses')),
      body: home.loading && home.myCourses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppTheme.accentPink,
              onRefresh: () => home.load(),
              child: home.myCourses.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 48),
                        Text(
                          'No purchased courses yet',
                          textAlign: TextAlign.center,
                          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      itemCount: home.myCourses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final c = home.myCourses[i] as Map<String, dynamic>;
                        return _MyCourseCard(course: c);
                      },
                    ),
            ),
    );
  }
}

class _MyCourseCard extends StatelessWidget {
  const _MyCourseCard({required this.course});

  final Map<String, dynamic> course;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final id = course['id'];
    final title = course['title']?.toString() ?? '';
    final imageUrl = course['image']?.toString() ?? '';
    final done = (course['lessons_completed'] as num?)?.toInt() ?? 0;
    final total = (course['lessons_total'] as num?)?.toInt() ?? 0;
    final xp = (course['xp_from_course'] as num?)?.toInt() ?? 0;
    final active = course['subscription_active'] == true;
    final expiresRaw = course['expires_at'] as String?;
    String statusLine;
    if (active) {
      statusLine = 'Subscription active';
    } else if (expiresRaw != null && expiresRaw.isNotEmpty) {
      final d = DateTime.tryParse(expiresRaw);
      statusLine = d != null
          ? 'Ended ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
          : 'Subscription ended';
    } else {
      statusLine = 'Subscription ended';
    }

    const imageSize = 100.0;
    const imageRadius = 14.0;

    return OmuzGlass(
      borderRadius: 14,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/course/$id'),
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white24,
          highlightColor: AppTheme.accentPink.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(imageRadius),
                  child: SizedBox(
                    width: imageSize,
                    height: imageSize,
                    child: imageUrl.isEmpty
                        ? ColoredBox(
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.school, color: cs.onSurfaceVariant, size: 36),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: cs.surfaceContainerHighest,
                              child: Icon(Icons.school, color: cs.onSurfaceVariant, size: 36),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          height: 1.2,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$done / $total lessons · $xp XP from this course',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: active ? Colors.green.shade700 : cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
