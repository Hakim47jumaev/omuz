import 'package:flutter/material.dart';

import '../../../core/widgets/omuz_ui.dart';
import '../data/admin_repository.dart';

int? _asIntId(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

class AdminDiscountsScreen extends StatefulWidget {
  const AdminDiscountsScreen({super.key});

  @override
  State<AdminDiscountsScreen> createState() => _AdminDiscountsScreenState();
}

class _AdminDiscountsScreenState extends State<AdminDiscountsScreen> {
  final _repo = AdminRepository();
  final _nameC = TextEditingController();
  final _percentC = TextEditingController(text: '10');
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 7));
  bool _loading = true;
  bool _saving = false;
  List<dynamic> _items = const [];
  List<dynamic> _categories = const [];
  List<dynamic> _courses = const [];

  String _scope = 'all';
  int? _categoryId;
  final Set<int> _selectedCourseIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _percentC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<List<dynamic>>([
        _repo.getDiscounts(),
        _repo.getCategories(),
        _repo.getCourses(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0];
        _categories = results[1];
        _courses = results[2];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _resolveCategoryDropdownValue(int? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c is! Map<String, dynamic>) continue;
      if (_asIntId(c['id']) == id) return id;
    }
    return null;
  }

  String _scopeSummary(Map<String, dynamic> d) {
    final s = d['scope'] as String? ?? 'all';
    if (s == 'all') return 'All paid courses';
    if (s == 'category') {
      final id = _asIntId(d['category']);
      if (id == null) return 'Category not set';
      for (final c in _categories) {
        if (c is! Map<String, dynamic>) continue;
        if (_asIntId(c['id']) == id) {
          return 'Category: ${c['name'] ?? id}';
        }
      }
      return 'Category #$id';
    }
    final ids = d['course_ids'] as List<dynamic>?;
    return 'Courses: ${ids?.length ?? 0} selected';
  }

  Map<String, dynamic> _payloadForScope() {
    final base = <String, dynamic>{
      'scope': _scope,
    };
    if (_scope == 'category' && _categoryId != null) {
      base['category'] = _categoryId;
    }
    if (_scope == 'courses') {
      base['course_ids'] = _selectedCourseIds.toList();
    }
    return base;
  }

  bool _validateScopeForSubmit() {
    if (_scope == 'category' && _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a category')),
      );
      return false;
    }
    if (_scope == 'courses' && _selectedCourseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one course')),
      );
      return false;
    }
    return true;
  }

  Widget _buildScopeEditor({
    required String scope,
    required void Function(String) onScope,
    required int? categoryId,
    required void Function(int?) onCategory,
    required Set<int> selectedCourseIds,
    required void Function(int id, bool selected) onCourseToggle,
    required void Function(void Function()) setLocal,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Applies to',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('All courses'), icon: Icon(Icons.public, size: 18)),
            ButtonSegment(value: 'category', label: Text('Category'), icon: Icon(Icons.folder_outlined, size: 18)),
            ButtonSegment(value: 'courses', label: Text('Courses'), icon: Icon(Icons.menu_book_outlined, size: 18)),
          ],
          selected: {scope},
          onSelectionChanged: (s) {
            setLocal(() => onScope(s.first));
          },
        ),
        if (scope == 'category') ...[
          const SizedBox(height: 12),
          if (_categories.isEmpty)
            Text(
              'Create categories first',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _resolveCategoryDropdownValue(categoryId),
                  hint: const Text('Pick a category'),
                  items: [
                    for (final c in _categories)
                      if (c is Map<String, dynamic> && _asIntId(c['id']) != null)
                        DropdownMenuItem<int>(
                          value: _asIntId(c['id'])!,
                          child: Text(
                            '${c['name'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  ],
                  onChanged: (v) => setLocal(() => onCategory(v)),
                ),
              ),
            ),
        ],
        if (scope == 'courses') ...[
          const SizedBox(height: 8),
          Text(
            'Select courses',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final raw in _courses)
                    Builder(
                      builder: (_) {
                        final co = Map<String, dynamic>.from(raw as Map);
                        final id = _asIntId(co['id']);
                        if (id == null) return const SizedBox.shrink();
                        final title = (co['title'] as String?) ?? '#$id';
                        final sel = selectedCourseIds.contains(id);
                        return FilterChip(
                          label: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: sel,
                          onSelected: (v) => setLocal(() => onCourseToggle(id, v)),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final current = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
      } else {
        _end = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  Future<void> _create() async {
    final percent = int.tryParse(_percentC.text.trim());
    if (_nameC.text.trim().isEmpty || percent == null) return;
    if (!_validateScopeForSubmit()) return;
    setState(() => _saving = true);
    try {
      await _repo.createDiscount({
        'name': _nameC.text.trim(),
        'percent': percent,
        'starts_at': _start.toUtc().toIso8601String(),
        'ends_at': _end.toUtc().toIso8601String(),
        'is_active': true,
        ..._payloadForScope(),
      });
      _nameC.clear();
      setState(() {
        _scope = 'all';
        _categoryId = null;
        _selectedCourseIds.clear();
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount created')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(int id) async {
    await _repo.deleteDiscount(id);
    await _load();
  }

  Future<void> _toggleActive(Map<String, dynamic> item, bool value) async {
    final id = item['id'] as int;
    await _repo.updateDiscount(id, {'is_active': value});
    await _load();
  }

  Future<void> _editDiscount(Map<String, dynamic> item) async {
    final id = item['id'] as int;
    final nameC = TextEditingController(text: (item['name'] as String?) ?? '');
    final percentC = TextEditingController(text: item['percent'].toString());
    var start = DateTime.tryParse((item['starts_at'] as String?) ?? '')?.toLocal() ??
        DateTime.now();
    var end = DateTime.tryParse((item['ends_at'] as String?) ?? '')?.toLocal() ??
        DateTime.now().add(const Duration(days: 7));
    var isActive = item['is_active'] == true;
    var saving = false;

    var scope = (item['scope'] as String?) ?? 'all';
    var categoryId = _asIntId(item['category']);
    final courseIdsRaw = item['course_ids'] as List<dynamic>?;
    var selectedCourses = <int>{
      for (final x in courseIdsRaw ?? const [])
        if (_asIntId(x) != null) _asIntId(x)!,
    };

    Future<void> pickDate(StateSetter setModalState, bool isStart) async {
      final current = isStart ? start : end;
      final picked = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked == null) return;
      final t = TimeOfDay.fromDateTime(current);
      setModalState(() {
        final dt = DateTime(picked.year, picked.month, picked.day, t.hour, t.minute);
        if (isStart) {
          start = dt;
        } else {
          end = dt;
        }
      });
    }

    Future<void> pickTime(StateSetter setModalState, bool isStart) async {
      final current = isStart ? start : end;
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (picked == null) return;
      setModalState(() {
        final dt = DateTime(
          current.year,
          current.month,
          current.day,
          picked.hour,
          picked.minute,
        );
        if (isStart) {
          start = dt;
        } else {
          end = dt;
        }
      });
    }

    bool validateEditScope() {
      if (scope == 'category' && categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a category')),
        );
        return false;
      }
      if (scope == 'courses' && selectedCourses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one course')),
        );
        return false;
      }
      return true;
    }

    Map<String, dynamic> editPayload() {
      final m = <String, dynamic>{
        'scope': scope,
      };
      if (scope == 'category' && categoryId != null) {
        m['category'] = categoryId;
      }
      if (scope == 'courses') {
        m['course_ids'] = selectedCourses.toList();
      }
      return m;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Edit discount',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: percentC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Percent (1–90)'),
                ),
                const SizedBox(height: 14),
                _buildScopeEditor(
                  scope: scope,
                  onScope: (v) => setModalState(() => scope = v),
                  categoryId: categoryId,
                  onCategory: (v) => setModalState(() => categoryId = v),
                  selectedCourseIds: selectedCourses,
                  onCourseToggle: (cid, sel) => setModalState(() {
                    if (sel) {
                      selectedCourses.add(cid);
                    } else {
                      selectedCourses.remove(cid);
                    }
                  }),
                  setLocal: setModalState,
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  onChanged: (v) => setModalState(() => isActive = v),
                  title: const Text('Active'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => pickDate(setModalState, true),
                        child: Text('Starts: ${_fmt(start)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => pickTime(setModalState, true),
                      icon: const Icon(Icons.access_time),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => pickDate(setModalState, false),
                        child: Text('Ends: ${_fmt(end)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => pickTime(setModalState, false),
                      icon: const Icon(Icons.access_time),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final p = int.tryParse(percentC.text.trim());
                          if (nameC.text.trim().isEmpty || p == null || start.isAfter(end)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Check fields and dates')),
                            );
                            return;
                          }
                          if (!validateEditScope()) return;
                          setModalState(() => saving = true);
                          try {
                            await _repo.updateDiscount(id, {
                              'name': nameC.text.trim(),
                              'percent': p,
                              'starts_at': start.toUtc().toIso8601String(),
                              'ends_at': end.toUtc().toIso8601String(),
                              'is_active': isActive,
                              ...editPayload(),
                            });
                            if (!context.mounted) return;
                            Navigator.pop(ctx);
                            await _load();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Discount updated')),
                            );
                          } finally {
                            if (ctx.mounted) setModalState(() => saving = false);
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discounts')),
      body: _loading
          ? OmuzPage.background(
              context: context,
              child: const Center(child: CircularProgressIndicator()),
            )
          : OmuzPage.background(
              context: context,
              child: ListView(
              padding: OmuzPage.padding,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _nameC,
                          decoration: const InputDecoration(
                            labelText: 'Discount name',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _percentC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Percent (1–90)',
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildScopeEditor(
                          scope: _scope,
                          onScope: (v) => setState(() => _scope = v),
                          categoryId: _categoryId,
                          onCategory: (v) => setState(() => _categoryId = v),
                          selectedCourseIds: _selectedCourseIds,
                          onCourseToggle: (cid, sel) => setState(() {
                            if (sel) {
                              _selectedCourseIds.add(cid);
                            } else {
                              _selectedCourseIds.remove(cid);
                            }
                          }),
                          setLocal: (fn) => setState(fn),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickDate(true),
                                child: Text('Starts: ${_start.toLocal().toString().split(' ').first}'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickDate(false),
                                child: Text('Ends: ${_end.toLocal().toString().split(' ').first}'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _saving ? null : _create,
                          child: Text(_saving ? 'Saving...' : 'Create discount'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ..._items.map((d) {
                  final id = d['id'] as int;
                  final isRunning = d['is_running'] == true;
                  final isActive = d['is_active'] == true;
                  final title = d['name'] as String? ?? 'Discount';
                  final percent = d['percent'].toString();
                  final map = d as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      title: Text('$title — $percent%'),
                      subtitle: Text(
                        '${_scopeSummary(map)}\n'
                        '${isRunning
                            ? 'Running now'
                            : (isActive ? 'On, outside date range' : 'Off')}',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: isActive,
                            onChanged: (v) => _toggleActive(map, v),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editDiscount(map),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(id),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
            ),
    );
  }
}
