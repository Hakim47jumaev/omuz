import 'package:flutter/material.dart';

import '../data/admin_repository.dart';

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
      final data = await _repo.getDiscounts();
      if (!mounted) return;
      setState(() => _items = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    setState(() => _saving = true);
    try {
      await _repo.createDiscount({
        'name': _nameC.text.trim(),
        'percent': percent,
        'starts_at': _start.toUtc().toIso8601String(),
        'ends_at': _end.toUtc().toIso8601String(),
        'is_active': true,
      });
      _nameC.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Скидка создана')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
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
                Text('Редактировать скидку',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: percentC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Процент (1..90)'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  onChanged: (v) => setModalState(() => isActive = v),
                  title: const Text('Активна'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => pickDate(setModalState, true),
                        child: Text('Старт: ${_fmt(start)}'),
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
                        child: Text('Конец: ${_fmt(end)}'),
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
                              const SnackBar(content: Text('Проверьте поля и даты')),
                            );
                            return;
                          }
                          setModalState(() => saving = true);
                          try {
                            await _repo.updateDiscount(id, {
                              'name': nameC.text.trim(),
                              'percent': p,
                              'starts_at': start.toUtc().toIso8601String(),
                              'ends_at': end.toUtc().toIso8601String(),
                              'is_active': isActive,
                            });
                            if (!context.mounted) return;
                            Navigator.pop(ctx);
                            await _load();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Скидка обновлена')),
                            );
                          } finally {
                            if (ctx.mounted) setModalState(() => saving = false);
                          }
                        },
                  child: Text(saving ? 'Сохранение...' : 'Сохранить'),
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
      appBar: AppBar(title: const Text('Глобальные скидки')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameC,
                          decoration: const InputDecoration(
                            labelText: 'Название скидки',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _percentC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Процент (1..90)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickDate(true),
                                child: Text('Старт: ${_start.toLocal().toString().split(' ').first}'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickDate(false),
                                child: Text('Конец: ${_end.toLocal().toString().split(' ').first}'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _saving ? null : _create,
                          child: Text(_saving ? 'Сохранение...' : 'Создать скидку'),
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
                  final title = d['name'] as String? ?? 'Скидка';
                  final percent = d['percent'].toString();
                  return Card(
                    child: ListTile(
                      title: Text('$title — $percent%'),
                      subtitle: Text(
                        isRunning
                            ? 'Активна сейчас'
                            : (isActive ? 'Включена, но вне периода' : 'Отключена'),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: isActive,
                            onChanged: (v) => _toggleActive(d as Map<String, dynamic>, v),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editDiscount(d as Map<String, dynamic>),
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
    );
  }
}
