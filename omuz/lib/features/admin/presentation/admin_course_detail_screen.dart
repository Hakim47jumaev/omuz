import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/omuz_ui.dart';
import '../data/admin_repository.dart';
import '../providers/admin_provider.dart';

class AdminCourseDetailScreen extends StatefulWidget {
  const AdminCourseDetailScreen({super.key, required this.courseId});

  final int courseId;

  @override
  State<AdminCourseDetailScreen> createState() => _AdminCourseDetailScreenState();
}

class _AdminCourseDetailScreenState extends State<AdminCourseDetailScreen> {
  final _repo = AdminRepository();
  bool _loading = true;
  String? _loadError;
  Map<String, dynamic>? _course;

  final _titleC = TextEditingController();
  final _descC = TextEditingController();
  final _imageC = TextEditingController();
  final _previewC = TextEditingController();
  final _priceC = TextEditingController();
  int? _categoryId;
  bool _published = true;
  bool _saving = false;

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _imageC.dispose();
    _previewC.dispose();
    _priceC.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final prov = context.read<AdminProvider>();
    try {
      if (prov.categories.isEmpty) {
        await prov.loadCategories();
      }
      final c = await _repo.getCourse(widget.courseId);
      if (!mounted) return;
      _applyCourse(c);
      setState(() {
        _course = c;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  void _applyCourse(Map<String, dynamic> c) {
    _titleC.text = c['title'] as String? ?? '';
    _descC.text = c['description'] as String? ?? '';
    _imageC.text = (c['image'] as String?)?.trim() ?? '';
    _previewC.text = (c['preview_video_url'] as String?)?.trim() ?? '';
    _priceC.text = c['price']?.toString() ?? '0';
    final cat = c['category'];
    if (cat is int) {
      _categoryId = cat;
    } else if (cat is num) {
      _categoryId = cat.toInt();
    } else {
      _categoryId = null;
    }
    _published = c['is_published'] == true;
  }

  Future<void> _save(AdminProvider prov) async {
    if (_categoryId == null || _titleC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title and pick a category')),
      );
      return;
    }
    setState(() => _saving = true);
    final parsedPrice = double.tryParse(_priceC.text.trim()) ?? 0;
    final data = <String, dynamic>{
      'title': _titleC.text.trim(),
      'description': _descC.text,
      'image': _imageC.text.trim(),
      'preview_video_url': _previewC.text.trim(),
      'price': parsedPrice < 0 ? 0 : parsedPrice,
      'category': _categoryId,
      'is_published': _published,
    };
    final ok = await prov.updateCourse(widget.courseId, data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course saved')),
      );
      final c = await _repo.getCourse(widget.courseId);
      if (mounted) {
        setState(() {
          _course = c;
          _applyCourse(c);
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(prov.error ?? 'Could not save')),
      );
    }
  }

  Future<void> _confirmDelete(AdminProvider prov) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete course?'),
        content: const Text(
          'Linked modules and lessons may be removed on the server. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    try {
      await prov.deleteCourse(widget.courseId);
      if (!mounted) return;
      context.go('/admin/courses');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdminProvider>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_course?['title'] as String? ?? 'Course'),
      ),
      body: _loading
          ? OmuzPage.background(
              context: context,
              child: const Center(child: CircularProgressIndicator()),
            )
          : _loadError != null
              ? OmuzPage.background(
                  context: context,
                  child: Center(
                    child: Padding(
                      padding: OmuzPage.padding,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  ),
                )
              : OmuzPage.background(
                  context: context,
                  child: ListView(
                    padding: OmuzPage.padding,
                    children: [
                      if (_imageC.text.isNotEmpty)
                        OmuzGlass(
                          borderRadius: 14,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                _imageC.text,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => ColoredBox(
                                  color: cs.surfaceContainerHighest,
                                  child: Icon(Icons.broken_image_outlined,
                                      size: 48, color: cs.onSurfaceVariant),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_imageC.text.isNotEmpty) const SizedBox(height: 16),
                      OmuzGlass(
                        borderRadius: 14,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Course details',
                                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _titleC,
                                decoration: const InputDecoration(
                                  labelText: 'Title',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _descC,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 4,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _imageC,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Cover image URL',
                                  border: OutlineInputBorder(),
                                  hintText: 'https://...',
                                ),
                                keyboardType: TextInputType.url,
                                autocorrect: false,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _previewC,
                                decoration: const InputDecoration(
                                  labelText: 'YouTube preview URL',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _priceC,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Price (TJS, 0 = free)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                value: _categoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  for (final raw in prov.categories)
                                    if (raw is Map<String, dynamic> && raw['id'] != null)
                                      DropdownMenuItem<int>(
                                        value: raw['id'] is int
                                            ? raw['id'] as int
                                            : (raw['id'] as num).toInt(),
                                        child: Text('${raw['name'] ?? ''}'),
                                      ),
                                ],
                                onChanged: (v) => setState(() => _categoryId = v),
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Published'),
                                value: _published,
                                onChanged: (v) => setState(() => _published = v),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _saving ? null : () => _save(prov),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_outlined),
                                  SizedBox(width: 8),
                                  Text('Save'),
                                ],
                              ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/admin/course/${widget.courseId}/modules'),
                        icon: const Icon(Icons.view_module_outlined),
                        label: const Text('Modules & lessons'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _confirmDelete(prov),
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        label: Text('Delete course', style: TextStyle(color: cs.error)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
