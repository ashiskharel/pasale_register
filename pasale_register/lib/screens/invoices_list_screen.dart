import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/keys.dart';
import '../models/store_invoice.dart';
import '../services/invoice_history_service.dart';
import '../services/service_locator.dart';
import '../theme/pasale_theme.dart';

/// Lists completed cart checkouts + manual invoices with cash/credit totals.
class InvoicesListScreen extends StatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen> {
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
    await _history.load(storeId: prefs.getString('storeId'));
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

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day  $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final invoices = _history.invoices;
    final totals = invoices.totals;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      key: AppKeys.invoicesListScreen,
      children: [
        Expanded(
          child: invoices.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No invoices yet.\nCheckout a cart or create a manual invoice.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: invoices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final inv = invoices[i];
                    final isCash = inv.isCash;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCash
                              ? scheme.primaryContainer
                              : scheme.tertiaryContainer,
                          child: Icon(
                            inv.source == InvoiceSource.manual
                                ? Icons.edit_note_outlined
                                : Icons.shopping_cart_checkout_outlined,
                            size: 20,
                            color: isCash
                                ? scheme.onPrimaryContainer
                                : scheme.onTertiaryContainer,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Rs. ${inv.total.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (inv.isPendingSync)
                              Tooltip(
                                message: 'Pending Sync (Offline)',
                                child: Icon(
                                  Icons.cloud_sync_outlined,
                                  size: 16,
                                  color: scheme.tertiary,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          [
                            _fmtDate(inv.createdAt),
                            inv.source == InvoiceSource.manual
                                ? 'Manual'
                                : 'Cart',
                            isCash ? 'Cash' : 'Credit',
                            if (inv.customerName != null &&
                                inv.customerName!.isNotEmpty)
                              inv.customerName!,
                            if (inv.customerPhone != null &&
                                inv.customerPhone!.isNotEmpty)
                              inv.customerPhone!,
                          ].join(' · '),
                        ),
                        isThreeLine: inv.lineSummary != null &&
                            inv.lineSummary!.isNotEmpty,
                        trailing: inv.lineSummary != null &&
                                inv.lineSummary!.isNotEmpty
                            ? Icon(
                                Icons.chevron_right,
                                color: scheme.onSurfaceVariant,
                              )
                            : null,
                        onTap: inv.lineSummary == null ||
                                inv.lineSummary!.isEmpty
                            ? null
                            : () {
                                showModalBottomSheet<void>(
                                  context: context,
                                  builder: (ctx) => SafeArea(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            'Invoice detail',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...inv.lineSummary!.map(
                                            (l) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Text(l),
                                            ),
                                          ),
                                          if (inv.notes != null) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              'Notes: ${inv.notes}',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                      ),
                    );
                  },
                ),
        ),
        Material(
          elevation: 6,
          color: scheme.surfaceContainerLowest,
          child: SafeArea(
            top: false,
            child: Container(
              key: AppKeys.invoiceTotalsBar,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: PasaleTheme.hairline),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Summary · ${totals.count} invoice${totals.count == 1 ? '' : 's'}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _totalRow(
                    theme,
                    'Cash (paid)',
                    totals.cashTotal,
                    scheme.primary,
                  ),
                  const SizedBox(height: 4),
                  _totalRow(
                    theme,
                    'Credit',
                    totals.creditTotal,
                    scheme.tertiary,
                  ),
                  const Divider(height: 16),
                  _totalRow(
                    theme,
                    'Total',
                    totals.grandTotal,
                    PasaleTheme.ink,
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalRow(
    ThemeData theme,
    String label,
    double amount,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ),
        Text(
          'Rs. ${amount.toStringAsFixed(2)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
