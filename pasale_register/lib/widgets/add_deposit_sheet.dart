import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/store_customer.dart';
import '../models/store_deposit.dart';
import '../models/store_invoice.dart';
import '../services/deposit_history_service.dart';
import '../services/service_locator.dart';

class AddDepositSheet extends StatefulWidget {
  final List<StoreCustomer> recentCustomers;

  const AddDepositSheet({super.key, required this.recentCustomers});

  static Future<void> show(
      BuildContext context, List<StoreCustomer> recentCustomers) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddDepositSheet(recentCustomers: recentCustomers),
    );
  }

  @override
  State<AddDepositSheet> createState() => _AddDepositSheetState();
}

class _AddDepositSheetState extends State<AddDepositSheet> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  InvoicePayment _payment = InvoicePayment.cash;
  bool _saving = false;
  StoreCustomer? _selectedCustomer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onCustomerSelected(StoreCustomer c) {
    setState(() {
      _selectedCustomer = c;
      _phoneCtrl.text = c.phone;
      _nameCtrl.text = c.name;
    });
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final phone = _phoneCtrl.text.trim();
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number is required')));
      return;
    }

    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final storeId = prefs.getString('storeId');
      if (storeId == null) throw Exception('No active store');

      final dep = StoreDeposit(
        id: '',
        createdAt: DateTime.now(),
        amount: amount,
        payment: _payment,
        customerPhone: phone,
        customerName: _nameCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        storeId: storeId,
      );

      await locator<DepositHistoryService>().add(dep);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom);

    return Padding(
      padding: viewInsets,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Record Customer Deposit',
                    style: theme.textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 16),
            Autocomplete<StoreCustomer>(
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<StoreCustomer>.empty();
                }
                final query = textEditingValue.text.toLowerCase();
                return widget.recentCustomers.where((c) =>
                    c.phone.toLowerCase().contains(query) ||
                    c.name.toLowerCase().contains(query));
              },
              displayStringForOption: (c) => c.phone,
              onSelected: _onCustomerSelected,
              fieldViewBuilder:
                  (context, textEditingController, focusNode, onFieldSubmitted) {
                if (_phoneCtrl.text.isEmpty && textEditingController.text.isNotEmpty) {
                  // Keep them in sync if typing manually
                  _phoneCtrl.text = textEditingController.text;
                }
                // Workaround to bind our controller to autocomplete's state
                textEditingController.addListener(() {
                  _phoneCtrl.text = textEditingController.text;
                });
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Customer Phone',
                    hintText: 'Search or enter new phone',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Customer Name (Optional)',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Deposit Amount',
                prefixText: 'Rs. ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            SegmentedButton<InvoicePayment>(
              segments: const [
                ButtonSegment(
                  value: InvoicePayment.cash,
                  label: Text('Cash'),
                  icon: Icon(Icons.money),
                ),
                ButtonSegment(
                  value: InvoicePayment.online,
                  label: Text('Online / Bank'),
                  icon: Icon(Icons.account_balance),
                ),
              ],
              selected: {_payment},
              onSelectionChanged: (set) => setState(() => _payment = set.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'e.g. Bank transfer reference',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Save Deposit', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
