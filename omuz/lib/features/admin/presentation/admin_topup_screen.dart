import 'package:flutter/material.dart';

import '../data/admin_repository.dart';

class AdminTopupScreen extends StatefulWidget {
  const AdminTopupScreen({super.key});

  @override
  State<AdminTopupScreen> createState() => _AdminTopupScreenState();
}

class _AdminTopupScreenState extends State<AdminTopupScreen> {
  final _repo = AdminRepository();
  List<dynamic> _users = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      _users = await _repo.getUsersWithBalance();
    } catch (e) {
      debugPrint('LOAD USERS ERROR: $e');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filteredUsers();

    return Scaffold(
      appBar: AppBar(title: const Text('Пополнение баланса')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Поиск по телефону, имени или фамилии',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Пользователи не найдены')),
                    )
                  else
                    ...filtered.map((u) {
                      final user = u as Map<String, dynamic>;
                      final name = '${user['first_name']} ${user['last_name']}'.trim();
                      final balance = user['balance'] as String? ?? '0.00';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: cs.outlineVariant),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(name.isNotEmpty ? name : 'User #${user['id']}'),
                          subtitle: Text('${user['phone']} | Баланс: $balance TJS'),
                          trailing: IconButton(
                            icon: Icon(Icons.add_circle, color: cs.primary),
                            onPressed: () => _showTopupDialog(user),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  List<dynamic> _filteredUsers() {
    if (_query.isEmpty) return _users;
    return _users.where((u) {
      final user = u as Map<String, dynamic>;
      final first = (user['first_name'] ?? '').toString().toLowerCase();
      final last = (user['last_name'] ?? '').toString().toLowerCase();
      final phone = (user['phone'] ?? '').toString().toLowerCase();
      final full = '$first $last';
      return phone.contains(_query) || first.contains(_query) || last.contains(_query) || full.contains(_query);
    }).toList();
  }

  void _showTopupDialog(Map<String, dynamic> user) {
    final ctrl = TextEditingController();
    final name = '${user['first_name']} ${user['last_name']}'.trim();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Пополнение: ${name.isNotEmpty ? name : user['phone']}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Сумма (TJS)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text.trim());
              if (amount == null || amount <= 0) return;
              Navigator.pop(ctx);
              try {
                await _repo.topUpUser(user['id'] as int, amount);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${amount.toStringAsFixed(2)} TJS зачислено')),
                  );
                  _loadUsers();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              }
            },
            child: const Text('Пополнить'),
          ),
        ],
      ),
    );
  }
}
