import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/keys.dart';
import '../models/store_invoice.dart';
import '../services/invoice_history_service.dart';
import '../services/service_locator.dart';

enum SalesPeriod { daily, weekly, monthly, yearly }

enum _DashDrill { none, revenue, orders, credit }

/// Store owner sales overview from real invoice history.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SalesPeriod _period = SalesPeriod.daily;
  _DashDrill _drill = _DashDrill.none;
  late final InvoiceHistoryService _history;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _history = locator.isRegistered<InvoiceHistoryService>()
        ? locator<InvoiceHistoryService>()
        : InvoiceHistoryService();
    _history.addListener(_onChange);
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString('storeId');
    await _history.load(storeId: storeId);
    if (mounted) setState(() => _loading = false);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _history.removeListener(_onChange);
    super.dispose();
  }

  (DateTime start, DateTime end) _rangeFor(SalesPeriod p) {
    final now = DateTime.now();
    final end = now.add(const Duration(days: 1));
    switch (p) {
      case SalesPeriod.daily:
        final start = DateTime(now.year, now.month, now.day);
        return (start, end);
      case SalesPeriod.weekly:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return (start, end);
      case SalesPeriod.monthly:
        return (DateTime(now.year, now.month, 1), end);
      case SalesPeriod.yearly:
        return (DateTime(now.year, 1, 1), end);
    }
  }

  List<StoreInvoice> get _periodInvoices {
    final (start, end) = _rangeFor(_period);
    return _history.invoicesInPeriod(start, end);
  }

  String _topSeller(List<StoreInvoice> list) {
    final counts = <String, int>{};
    for (final inv in list) {
      for (final line in inv.lineSummary ?? const <String>[]) {
        final name = line.split(' x').first.trim();
        if (name.isEmpty) continue;
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return '—';
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_drill != _DashDrill.none) {
      return _drillDown(theme);
    }

    final list = _periodInvoices;
    final totals = list.totals;
    final revenue = totals.grandTotal;
    final orders = totals.count;
    final credit = totals.creditTotal;
    final top = _topSeller(list);

    return ListView(
      key: AppKeys.dashboardScreen,
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<SalesPeriod>(
          segments: const [
            ButtonSegment(
              value: SalesPeriod.daily,
              label: Text('Day'),
              icon: Icon(Icons.today, size: 16),
            ),
            ButtonSegment(
              value: SalesPeriod.weekly,
              label: Text('Week'),
              icon: Icon(Icons.date_range, size: 16),
            ),
            ButtonSegment(
              value: SalesPeriod.monthly,
              label: Text('Month'),
              icon: Icon(Icons.calendar_month, size: 16),
            ),
            ButtonSegment(
              value: SalesPeriod.yearly,
              label: Text('Year'),
              icon: Icon(Icons.calendar_today, size: 16),
            ),
          ],
          selected: {_period},
          onSelectionChanged: (s) => setState(() => _period = s.first),
        ),
        const SizedBox(height: 20),
        _MetricCard(
          title: 'Revenue',
          value: 'Rs. ${_format(revenue)}',
          icon: Icons.payments_outlined,
          color: theme.colorScheme.primary,
          onTap: () => setState(() => _drill = _DashDrill.revenue),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Orders',
                value: '$orders',
                icon: Icons.shopping_cart_outlined,
                color: Colors.indigo,
                compact: true,
                onTap: () => setState(() => _drill = _DashDrill.orders),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'On credit',
                value: 'Rs. ${_format(credit)}',
                icon: Icons.credit_score_outlined,
                color: Colors.orange.shade800,
                compact: true,
                onTap: () => setState(() => _drill = _DashDrill.credit),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Top seller'),
            subtitle: Text(top),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Live from your checkouts & manual invoices'
          '${_history.storeId != null ? ' · store ${_history.storeId}' : ''}. '
          'Tap a metric to open related records.',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _drillDown(ThemeData theme) {
    final all = _periodInvoices;
    final list = switch (_drill) {
      _DashDrill.credit => all.where((i) => i.isCredit).toList(),
      _DashDrill.revenue || _DashDrill.orders => all,
      _DashDrill.none => all,
    };
    final title = switch (_drill) {
      _DashDrill.revenue => 'Revenue details',
      _DashDrill.orders => 'Orders (invoices)',
      _DashDrill.credit => 'On credit',
      _DashDrill.none => 'Details',
    };
    final totals = list.totals;

    return Column(
      children: [
        Material(
          color: theme.colorScheme.surface,
          child: ListTile(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _drill = _DashDrill.none),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${list.length} record${list.length == 1 ? '' : 's'} · '
              'Rs. ${totals.grandTotal.toStringAsFixed(2)}',
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    'No invoices in this period.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final inv = list[i];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          inv.isCredit
                              ? Icons.schedule
                              : Icons.payments_outlined,
                        ),
                        title: Text(
                          'Rs. ${inv.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          [
                            inv.createdAt.toLocal().toString().substring(0, 16),
                            inv.isCash ? 'Cash' : 'Credit',
                            inv.source == InvoiceSource.manual
                                ? 'Manual'
                                : 'Cart',
                            if (inv.customerName != null) inv.customerName!,
                            if (inv.customerPhone != null) inv.customerPhone!,
                          ].join(' · '),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
        if (list.isNotEmpty)
          Material(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                children: [
                  _sumRow('Cash', totals.cashTotal),
                  _sumRow('Credit', totals.creditTotal),
                  const Divider(),
                  _sumRow('Total', totals.grandTotal, bold: true),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _sumRow(String label, double amount, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          'Rs. ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _format(num n) {
    if (n >= 100000) {
      return '${(n / 100000).toStringAsFixed(1)}L';
    }
    if (n >= 1000) {
      return n.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
    }
    return n.toStringAsFixed(0);
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.compact = false,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
          padding: EdgeInsets.all(compact ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                ],
              ),
              SizedBox(height: compact ? 10 : 14),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 18 : 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
