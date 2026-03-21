import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(context, 'Resume', Icons.description, '/resume'),
          _tile(context, 'Analytics', Icons.analytics, '/admin/analytics'),
          _tile(context, 'Discounts', Icons.local_offer, '/admin/discounts'),
          _tile(context, 'Payments', Icons.payments, '/admin/payments'),
          _tile(context, 'Top Up Users', Icons.account_balance_wallet, '/admin/topup'),
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
