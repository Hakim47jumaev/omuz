import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/admin_provider.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<AdminProvider>();
    Future.microtask(() => prov.loadCategories());
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, prov),
        child: const Icon(Icons.add),
      ),
      body: prov.loading && prov.categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: prov.categories.length,
              itemBuilder: (context, index) {
                final cat = prov.categories[index] as Map<String, dynamic>;
                return Card(
                  child: ListTile(
                    title: Text(cat['name'] as String),
                    subtitle: Text(cat['icon'] as String? ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => prov.deleteCategory(cat['id'] as int),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddDialog(BuildContext context, AdminProvider prov) {
    final nameC = TextEditingController();
    final iconC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: iconC, decoration: const InputDecoration(labelText: 'Icon (emoji)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await prov.createCategory(nameC.text, iconC.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
