import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/omuz_ui.dart';
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
      appBar: AppBar(title: const Text('Transactions')),
      body: prov.transactions.isEmpty
          ? OmuzPage.background(
              context: context,
              child: Center(
                child: Text(
                  'No transactions yet',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          : OmuzPage.background(
              context: context,
              child: RefreshIndicator(
                onRefresh: () => prov.loadTransactions(),
                child: ListView.builder(
                  padding: OmuzPage.padding,
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
                            ? AppTheme.success.withValues(alpha: 0.15)
                            : AppTheme.danger.withValues(alpha: 0.15),
                        child: Icon(
                          isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isPositive ? AppTheme.success : AppTheme.danger,
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
                          color: isPositive ? AppTheme.success : AppTheme.danger,
                        ),
                      ),
                    ),
                  );
                  },
                ),
              ),
            ),
    );
  }

  String _formatType(String type) {
    switch (type) {
      case 'topup':
        return 'Top-up';
      case 'purchase':
        return 'Course purchase';
      case 'renewal':
        return 'Subscription renewal';
      default:
        return type;
    }
  }
}
