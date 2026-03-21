import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<ProfileProvider>();
    Future.microtask(() => prov.loadTransactions());
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProfileProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Операции')),
      body: prov.transactions.isEmpty
          ? const Center(child: Text('Операций пока нет'))
          : RefreshIndicator(
              onRefresh: () => prov.loadTransactions(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: prov.transactions.length,
                itemBuilder: (_, i) {
                  final t = prov.transactions[i] as Map<String, dynamic>;
                  final amount = double.tryParse(t['amount'].toString()) ?? 0;
                  final isPositive = amount > 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isPositive
                            ? Colors.green.withAlpha(30)
                            : Colors.red.withAlpha(30),
                        child: Icon(
                          isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isPositive ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ),
                      title: Text(t['description'] as String),
                      subtitle: Text(
                        _formatType(t['type'] as String),
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                      trailing: Text(
                        '${isPositive ? "+" : ""}${amount.toStringAsFixed(2)} TJS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _formatType(String type) {
    switch (type) {
      case 'topup':
        return 'Пополнение';
      case 'purchase':
        return 'Оплата курса';
      case 'renewal':
        return 'Продление подписки';
      default:
        return type;
    }
  }
}
