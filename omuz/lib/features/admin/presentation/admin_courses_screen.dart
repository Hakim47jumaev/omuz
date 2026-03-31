import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/omuz_ui.dart';
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

  String _categoryName(AdminProvider prov, Map<String, dynamic> course) {
    final id = course['category'];
    int? cid;
    if (id is int) cid = id;
    if (id is num) cid = id.toInt();
    if (cid == null) return '';
    for (final raw in prov.categories) {
      if (raw is! Map<String, dynamic>) continue;
      final rid = raw['id'];
      final ridi = rid is int ? rid : (rid is num ? rid.toInt() : null);
      if (ridi == cid) return (raw['name'] as String?) ?? '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdminProvider>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Courses')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCourseDialog(context, prov),
        child: const Icon(Icons.add),
      ),
      body: prov.loading && prov.courses.isEmpty
          ? OmuzPage.background(
              context: context,
              child: const Center(child: CircularProgressIndicator()),
            )
          : OmuzPage.background(
              context: context,
              child: ListView.separated(
                padding: OmuzPage.padding,
                itemCount: prov.courses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final course = prov.courses[index] as Map<String, dynamic>;
                  final id = course['id'] as int;
                  final imageUrl = (course['image'] as String?)?.trim() ?? '';
                  final title = course['title'] as String? ?? 'Course';
                  final cat = _categoryName(prov, course);
                  final published = course['is_published'] == true;
                  final desc = (course['description'] as String?)?.trim() ?? '';
                  final subParts = <String>[];
                  if (cat.isNotEmpty) subParts.add(cat);
                  if (!published) subParts.add('draft');
                  final subLine = subParts.isEmpty
                      ? (desc.isEmpty ? 'Tap to open' : desc)
                      : '${subParts.join(' · ')}${desc.isEmpty ? '' : '\n$desc'}';

                  return OmuzGlass(
                    borderRadius: 14,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/admin/course/$id'),
                        borderRadius: BorderRadius.circular(14),
                        splashColor: Colors.white24,
                        highlightColor: AppTheme.accentPink.withValues(alpha: 0.12),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _courseListThumbnail(context, imageUrl),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurface,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subLine,
                                      maxLines: published ? 2 : 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: cs.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showCourseDialog(BuildContext context, AdminProvider prov, {Map<String, dynamic>? course}) {
    final isEdit = course != null;
    final titleC = TextEditingController(text: isEdit ? course['title'] as String : '');
    final descC = TextEditingController(text: isEdit ? (course['description'] as String? ?? '') : '');
    final imageC = TextEditingController(text: isEdit ? (course['image'] as String? ?? '') : '');
    final previewC = TextEditingController(text: isEdit ? (course['preview_video_url'] as String? ?? '') : '');
    final priceC = TextEditingController(
      text: isEdit ? (course['price']?.toString() ?? '0') : '0',
    );
    int? selectedCatId = isEdit ? course['category'] as int? : null;
    var published = isEdit ? (course['is_published'] == true) : true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit course' : 'New course'),
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
                TextField(
                  controller: imageC,
                  decoration: const InputDecoration(
                    labelText: 'Cover image URL',
                    hintText: 'https://...',
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: previewC,
                  decoration: const InputDecoration(
                    labelText: 'YouTube preview URL',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Price (TJS, 0 = free)',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedCatId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: prov.categories.map((c) {
                    final cat = c as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: cat['id'] as int,
                      child: Text(cat['name'] as String),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedCatId = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Published'),
                  value: published,
                  onChanged: (v) => setDialogState(() => published = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (selectedCatId == null || titleC.text.isEmpty) return;
                final parsedPrice = double.tryParse(priceC.text.trim()) ?? 0;
                final data = {
                  'title': titleC.text,
                  'description': descC.text,
                  'image': imageC.text.trim(),
                  'preview_video_url': previewC.text.trim(),
                  'price': parsedPrice < 0 ? 0 : parsedPrice,
                  'category': selectedCatId,
                  'is_published': published,
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

  static Widget _courseListThumbnail(BuildContext context, String imageUrl) {
    final cs = Theme.of(context).colorScheme;
    const size = 72.0;
    if (imageUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: cs.surfaceContainerHighest,
        ),
        child: Icon(Icons.school_outlined, color: cs.onSurfaceVariant, size: 32),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => ColoredBox(
            color: cs.surfaceContainerHighest,
            child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
