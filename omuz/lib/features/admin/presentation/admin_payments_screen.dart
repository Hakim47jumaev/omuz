import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/widgets/omuz_ui.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  final _dio = ApiClient().dio;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _period = '1m';
  DateTime? _customStart;
  DateTime? _customEnd;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get(
        Endpoints.paymentAnalytics,
        queryParameters: _buildQuery(),
      );
      _data = res.data as Map<String, dynamic>;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> _buildQuery() {
    final q = <String, dynamic>{'period': _period};
    if (_period == 'custom' && _customStart != null && _customEnd != null) {
      q['start_date'] = _fmtDate(_customStart!);
      q['end_date'] = _fmtDate(_customEnd!);
    }
    return q;
  }

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _pickCustomDates() async {
    final now = DateTime.now();
    final start = await showDatePicker(
      context: context,
      initialDate: _customStart ?? now.subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (start == null || !mounted) return;
    final end = await showDatePicker(
      context: context,
      initialDate: _customEnd ?? now,
      firstDate: start,
      lastDate: now,
    );
    if (end == null) return;
    setState(() {
      _customStart = start;
      _customEnd = end;
      _period = 'custom';
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: _loading
          ? OmuzPage.background(
              context: context,
              child: const Center(child: CircularProgressIndicator()),
            )
          : _data == null
              ? OmuzPage.background(
                  context: context,
                  child: Center(
                    child: Text(
                      'Could not load data',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : OmuzPage.background(
                  context: context,
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: OmuzPage.padding,
                      children: [
                        _buildFilters(),
                        const SizedBox(height: 12),
                        _buildPayments(),
                        const SizedBox(height: 16),
                        _buildTransactions(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Period'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _periodChip('10d', '10 days'),
                _periodChip('1m', 'Month'),
                _periodChip('6m', '6 months'),
                _periodChip('all', 'All time'),
                OutlinedButton.icon(
                  onPressed: _pickCustomDates,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _customStart != null && _customEnd != null
                        ? '${_fmtDate(_customStart!)} - ${_fmtDate(_customEnd!)}'
                        : 'Custom range',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(String code, String label) {
    final selected = _period == code;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) async {
        setState(() => _period = code);
        await _load();
      },
    );
  }

  Widget _buildPayments() {
    final p = _data!['payments'] as Map<String, dynamic>? ?? {};
    final period = _data!['period'] as Map<String, dynamic>? ?? {};
    final topSpenders = p['top_spenders'] as List<dynamic>? ?? [];
    final dailyRevenue = p['daily_revenue'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment analytics', style: Theme.of(context).textTheme.titleMedium),
            if ((period['start']?.toString().isNotEmpty ?? false) &&
                (period['end']?.toString().isNotEmpty ?? false)) ...[
              const SizedBox(height: 6),
              Text(
                'Period: ${_fmtIsoToDate(period['start'].toString())} - ${_fmtIsoToDate(period['end'].toString())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            _row('Total transactions', p['transactions_total'] ?? 0, Icons.receipt_long, Colors.blue),
            _row('Top-ups', p['topups_count'] ?? 0, Icons.add_card, Colors.green),
            _row('Purchases', p['purchases_count'] ?? 0, Icons.shopping_cart, Colors.orange),
            _row('Renewals', p['renewals_count'] ?? 0, Icons.autorenew, Colors.purple),
            const Divider(),
            _row('Total topped up', _money(p['total_topped_up']), Icons.account_balance_wallet, Colors.green),
            _row('Total spent', _money(p['total_spent']), Icons.payments, Colors.red),
            _row('Purchase revenue', _money(p['purchase_revenue']), Icons.monetization_on, Colors.teal),
            _row('Renewal revenue', _money(p['renewal_revenue']), Icons.currency_exchange, Colors.indigo),
            _row('Average transaction', _money(p['avg_transaction_amount']), Icons.calculate, Colors.brown),
            if (topSpenders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Top spenders', style: Theme.of(context).textTheme.titleSmall),
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
              Text('Daily revenue (last 14 days)', style: Theme.of(context).textTheme.titleSmall),
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
    final filtered = tx.where((item) {
      if (_searchQuery.trim().isEmpty) return true;
      final row = item as Map<String, dynamic>;
      final name = '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'
          .trim()
          .toLowerCase();
      final phone = (row['phone']?.toString() ?? '').toLowerCase();
      final query = _searchQuery.trim().toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent transactions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search learner: phone or name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              const Text('No transactions yet')
            else
              ...filtered.take(40).map((t) {
                final row = t as Map<String, dynamic>;
                final txId = row['id'] as int?;
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
                  title: Text(name.isNotEmpty ? name : row['phone']?.toString() ?? 'User'),
                  subtitle: Text('${row['type_label']} • ${row['description']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _money(amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'PDF check',
                        icon: const Icon(Icons.receipt_long_outlined, size: 20),
                        onPressed: txId == null ? null : () => _downloadCheck(txId),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadCheck(int txId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/payment_check_$txId.pdf';
      await _dio.download(
        Endpoints.adminTransactionCheck(txId),
        path,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check saved, opening...')),
      );
      await OpenFilex.open(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate check: $e')),
      );
    }
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

  String _fmtIsoToDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d.$m.$y';
  }
}
