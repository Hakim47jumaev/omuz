import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(context, 'Analytics', Icons.analytics, '/admin/analytics'),
          _tile(context, 'Categories', Icons.category, '/admin/categories'),
          _tile(context, 'Courses', Icons.school, '/admin/courses'),
        ],
      ),
    );
  }

  Widget _tile(BuildContext ctx, String title, IconData icon, String route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => ctx.push(route),
      ),
    );
  }
}
