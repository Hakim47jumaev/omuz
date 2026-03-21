import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<void> _openNotification(Map<String, dynamic> n) async {
    final prov = context.read<ProfileProvider>();
    final id = n['id'] as int;
    await prov.readNotification(id);
    if (!mounted) return;
    final route = (n['target_route'] as String? ?? '').trim();
    if (route.isNotEmpty) {
      try {
        context.push(route);
      } catch (_) {
        context.push('/notifications/$id');
      }
      return;
    }
    context.push('/notifications/$id');
  }

  @override
  void initState() {
    super.initState();
    final prov = context.read<ProfileProvider>();
    Future.microtask(prov.loadNotifications);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProfileProvider>();
    final items = prov.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          TextButton(
            onPressed: items.isEmpty ? null : () => prov.readAllNotifications(),
            child: const Text('Прочитать все'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => prov.loadNotifications(),
        child: items.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: 180),
                  Center(child: Text('Нет уведомлений')),
                ],
              )
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final n = items[i] as Map<String, dynamic>;
                  final isRead = n['is_read'] == true;
                  return ListTile(
                    onTap: () => _openNotification(n),
                    leading: Icon(
                      isRead ? Icons.notifications_none : Icons.notifications_active,
                    ),
                    title: Text(n['title'] as String? ?? ''),
                    subtitle: Text(n['body'] as String? ?? ''),
                    trailing: isRead
                        ? null
                        : const Icon(Icons.brightness_1, color: Colors.red, size: 10),
                  );
                },
              ),
      ),
    );
  }
}
