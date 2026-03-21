import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';

class NotificationDetailScreen extends StatefulWidget {
  final int id;
  const NotificationDetailScreen({super.key, required this.id});

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<ProfileProvider>();
    Future.microtask(() async {
      await prov.readNotification(widget.id);
      await prov.loadNotificationById(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProfileProvider>();
    final item = prov.currentNotification;
    if (item == null || item['id'] != widget.id) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомление')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['title'] as String? ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              item['type'] as String? ?? 'system',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(item['body'] as String? ?? ''),
            const SizedBox(height: 16),
            if (((item['target_route'] as String?) ?? '').trim().isNotEmpty)
              FilledButton.icon(
                onPressed: () {
                  final route = (item['target_route'] as String).trim();
                  if (route.isNotEmpty) {
                    try {
                      context.push(route);
                    } catch (_) {
                      context.push('/notifications/${item['id']}');
                    }
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Перейти'),
              ),
          ],
        ),
      ),
    );
  }
}
