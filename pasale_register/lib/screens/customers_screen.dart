import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/keys.dart';
import '../models/store_customer.dart';
import '../models/store_invoice.dart';
import '../models/store_deposit.dart';
import '../services/invoice_history_service.dart';
import '../services/deposit_history_service.dart';
import '../services/service_locator.dart';
import '../widgets/add_deposit_sheet.dart';
/// Recent customers (max 10) with search, balance, and last 10 transactions.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _search = TextEditingController();
  late final InvoiceHistoryService _history;
  late final DepositHistoryService _depositHistory;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _history = locator.isRegistered<InvoiceHistoryService>()
        ? locator<InvoiceHistoryService>()
        : InvoiceHistoryService();
    _depositHistory = locator.isRegistered<DepositHistoryService>()
        ? locator<DepositHistoryService>()
        : DepositHistoryService();
    _history.addListener(_onChange);
    _depositHistory.addListener(_onChange);
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final sid = prefs.getString('storeId');
    await Future.wait([
      _history.load(storeId: sid),
      _depositHistory.load(storeId: sid),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _history.removeListener(_onChange);
    _depositHistory.removeListener(_onChange);
    _search.dispose();
    super.dispose();
  }

  List<StoreCustomer> get _visible =>
      _history.recentCustomers(limit: 10, query: _search.text);

  Future<void> _editOrVoidTransaction(dynamic tx, bool isDeposit) async {
    final bool isVoided = isDeposit ? (tx as StoreDeposit).isVoided : (tx as StoreInvoice).isVoided;
    if (isVoided) return;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDeposit ? 'Manage Deposit' : 'Manage Invoice'),
        content: const Text('Would you like to edit or void this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'edit'),
            child: const Text('Edit'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, 'void'),
            child: const Text('Void'),
          ),
        ],
      ),
    );

    if (result == 'void') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Void'),
          content: const Text('Are you sure you want to void this transaction? This cannot be fully undone and will adjust the customer\'s balance.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Void Transaction'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        if (isDeposit) {
          await _depositHistory.add((tx as StoreDeposit).copyWith(isVoided: true));
        } else {
          await _history.add((tx as StoreInvoice).copyWith(isVoided: true));
        }
        _onChange();
      }
    } else if (result == 'edit') {
      final amountCtrl = TextEditingController(text: isDeposit ? (tx as StoreDeposit).amount.toString() : (tx as StoreInvoice).total.toString());
      final notesCtrl = TextEditingController(text: isDeposit ? (tx as StoreDeposit).notes ?? '' : (tx as StoreInvoice).notes ?? '');
      final editResult = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isDeposit ? 'Edit Deposit' : 'Edit Invoice'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                decoration: InputDecoration(labelText: isDeposit ? 'Amount' : 'Total Amount'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (editResult == true) {
        final amount = double.tryParse(amountCtrl.text) ?? 0.0;
        final notes = notesCtrl.text.trim();
        if (isDeposit) {
          await _depositHistory.add((tx as StoreDeposit).copyWith(amount: amount, notes: notes.isEmpty ? null : notes));
        } else {
          await _history.add((tx as StoreInvoice).copyWith(total: amount, notes: notes.isEmpty ? null : notes));
        }
        _onChange();
      }
    }
  }

  Future<void> _openCustomer(StoreCustomer c) async {
    final invs = _history.transactionsForPhone(c.phone, limit: 10);
    final deps = _depositHistory.deposits.where((d) => d.customerPhone == c.phone).take(10).toList();
    
    final txs = <dynamic>[...invs, ...deps];
    txs.sort((a, b) => (b.createdAt as DateTime).compareTo(a.createdAt as DateTime));
    final displayTxs = txs.take(10).toList();

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (ctx, scroll) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(c.phone),
                            if (c.email != null && c.email!.isNotEmpty)
                              Text(
                                c.email!,
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      c.creditBalance > 0
                          ? 'Balance (on credit): Rs. ${c.creditBalance.toStringAsFixed(2)}'
                          : (c.creditBalance < 0
                              ? 'Balance (deposit): Rs. ${c.creditBalance.abs().toStringAsFixed(2)}'
                              : 'Balance: settled'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c.creditBalance > 0
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Last ${displayTxs.length} transaction${displayTxs.length == 1 ? '' : 's'}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: displayTxs.isEmpty
                      ? const Center(child: Text('No transactions yet'))
                      : ListView.separated(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          itemCount: displayTxs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final tx = displayTxs[i];
                            final isDeposit = tx is! StoreInvoice;
                            final amount = isDeposit ? (tx as dynamic).amount : (tx as StoreInvoice).total;
                            final payment = isDeposit ? (tx as dynamic).payment : (tx as StoreInvoice).payment;
                            final isVoided = isDeposit ? (tx as dynamic).isVoided : (tx as StoreInvoice).isVoided;
                            final isCash = payment == InvoicePayment.cash;
                            final isCredit = payment == InvoicePayment.credit;
                            return Card(
                              child: ListTile(
                                onTap: () {
                                  Navigator.pop(context); // Close bottom sheet
                                  _editOrVoidTransaction(tx, isDeposit).then((_) {
                                    if (mounted) _openCustomer(c); // Re-open after done
                                  });
                                },
                                dense: true,
                                title: Text(
                                  'Rs. ${amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    decoration: isVoided ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    tx.createdAt
                                        .toLocal()
                                        .toString()
                                        .substring(0, 16),
                                    if (isDeposit) 'Deposit' else (isCash ? 'Cash' : 'Credit'),
                                    if (!isDeposit) ((tx as StoreInvoice).source == InvoiceSource.manual ? 'Manual' : 'Cart'),
                                    if (isVoided) 'VOIDED',
                                  ].join(' · '),
                                ),
                                trailing: Text(
                                  isDeposit
                                      ? '-${amount.toStringAsFixed(0)}'
                                      : (isCredit
                                          ? '+${amount.toStringAsFixed(0)}'
                                          : 'paid'),
                                  style: TextStyle(
                                    color: isVoided ? Colors.grey : (isCredit && !isDeposit
                                        ? Colors.red.shade700
                                        : Colors.green.shade700),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    decoration: isVoided ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final customers = _visible;

    return Column(
      key: AppKeys.customersScreen,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            key: AppKeys.customerSearchInput,
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Search customers',
              hintText: 'Name or phone',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: () => AddDepositSheet.show(context, _history.recentCustomers(limit: 50)),
            icon: const Icon(Icons.account_balance_wallet),
            label: const Text('Record Customer Deposit'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              customers.isEmpty
                  ? 'No customers yet (credit/cash with phone will appear here)'
                  : 'Showing ${customers.length} recent'
                      '${_search.text.trim().isEmpty ? '' : ' match${customers.length == 1 ? '' : 'es'}'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: customers.isEmpty
              ? Center(
                  child: Text(
                    'Add sales with a customer phone to build this list.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = customers[i];
                    final credit = c.creditBalance > 0;
                    final initial = c.name.isNotEmpty
                        ? c.name.characters.first.toUpperCase()
                        : '?';
                    return Card(
                      child: ListTile(
                        onTap: () => _openCustomer(c),
                        leading: CircleAvatar(child: Text(initial)),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(c.phone),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              c.creditBalance > 0
                                  ? 'Credit Rs. ${c.creditBalance.toStringAsFixed(0)}'
                                  : (c.creditBalance < 0
                                      ? 'Deposit Rs. ${c.creditBalance.abs().toStringAsFixed(0)}'
                                      : 'Settled'),
                              style: TextStyle(
                                color: c.creditBalance > 0
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 28),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _openCustomer(c),
                              child: const Text('View more'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
