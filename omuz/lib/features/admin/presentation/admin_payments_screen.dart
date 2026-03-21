import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  final _dio = ApiClient().dio;
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get(Endpoints.paymentAnalytics);
      _data = res.data as Map<String, dynamic>;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Платежи')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Не удалось загрузить данные'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildPayments(),
                      const SizedBox(height: 16),
                      _buildTransactions(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPayments() {
    final p = _data!['payments'] as Map<String, dynamic>? ?? {};
    final topSpenders = p['top_spenders'] as List<dynamic>? ?? [];
    final dailyRevenue = p['daily_revenue'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Аналитика платежей', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _row('Всего транзакций', p['transactions_total'] ?? 0, Icons.receipt_long, Colors.blue),
            _row('Пополнения', p['topups_count'] ?? 0, Icons.add_card, Colors.green),
            _row('Покупки', p['purchases_count'] ?? 0, Icons.shopping_cart, Colors.orange),
            _row('Продления', p['renewals_count'] ?? 0, Icons.autorenew, Colors.purple),
            const Divider(),
            _row('Сумма пополнений', _money(p['total_topped_up']), Icons.account_balance_wallet, Colors.green),
            _row('Сумма списаний', _money(p['total_spent']), Icons.payments, Colors.red),
            _row('Доход от покупок', _money(p['purchase_revenue']), Icons.monetization_on, Colors.teal),
            _row('Доход от продлений', _money(p['renewal_revenue']), Icons.currency_exchange, Colors.indigo),
            _row('Средний чек', _money(p['avg_transaction_amount']), Icons.calculate, Colors.brown),
            if (topSpenders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Топ пользователей по расходам', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...topSpenders.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value as Map<String, dynamic>;
                final name = '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 11))),
                  title: Text(name.isNotEmpty ? name : 'User #${s['user_id']}'),
                  trailing: Text(_money(s['spent']), style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              }),
            ],
            if (dailyRevenue.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Выручка по дням (последние 14 дней)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...dailyRevenue.map((d) {
                final row = d as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.calendar_today, size: 16),
                  title: Text(row['day']?.toString() ?? '-'),
                  trailing: Text(_money(row['amount'])),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactions() {
    final tx = _data!['transactions'] as List<dynamic>? ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Последние транзакции', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (tx.isEmpty)
              const Text('Транзакций пока нет')
            else
              ...tx.take(30).map((t) {
                final row = t as Map<String, dynamic>;
                final amount = row['amount']?.toString() ?? '0';
                final isPositive = !amount.startsWith('-');
                final name = '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim();
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isPositive ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  title: Text(name.isNotEmpty ? name : row['phone']?.toString() ?? 'Пользователь'),
                  subtitle: Text('${row['type_label']} • ${row['description']}'),
                  trailing: Text(
                    _money(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, dynamic value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _money(dynamic value) => '$value TJS';
}
