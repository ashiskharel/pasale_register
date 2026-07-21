import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/keys.dart';
import '../models/store_customer.dart';
import '../models/store_invoice.dart';
import '../services/invoice_history_service.dart';
import '../services/service_locator.dart';
import '../services/sharing_service.dart';
import '../theme/pasale_theme.dart';
import '../utils/bill_formatter.dart';

/// Store owner: create a simple manual invoice (date, total, phone, paid/credit)
/// and send it to the customer.
class ManualInvoiceScreen extends StatefulWidget {
  const ManualInvoiceScreen({super.key});

  @override
  State<ManualInvoiceScreen> createState() => _ManualInvoiceScreenState();
}

class _ManualInvoiceScreenState extends State<ManualInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _totalController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _date = DateTime.now();
  bool _isPaid = true;
  bool _busy = false;
  String _status = '';
  String _storeName = 'Pasale';

  @override
  void initState() {
    super.initState();
    _loadStoreName();
  }

  Future<void> _loadStoreName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('storeName');
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _storeName = name);
    }
  }

  @override
  void dispose() {
    _totalController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  String get _dateLabel {
    final y = _date.year.toString().padLeft(4, '0');
    final m = _date.month.toString().padLeft(2, '0');
    final d = _date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty) {
      setState(() => _status = 'Customer name is required');
      return;
    }
    if (!BillFormatter.isValidNepaliPhoneNumber(phone)) {
      setState(() {
        _status = 'Enter a valid mobile (98/97XXXXXXXX)';
      });
      return;
    }

    final total = double.parse(_totalController.text.trim());
    final notes = _notesController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString('storeId');

    setState(() {
      _busy = true;
      _status = '';
    });

    final text = BillFormatter.generateManualInvoice(
      storeName: _storeName,
      date: _date,
      totalPrice: total,
      customerPhone: phone,
      isPaid: _isPaid,
      notes: notes.isEmpty ? null : notes,
    );

    try {
      if (locator.isRegistered<InvoiceHistoryService>()) {
        await locator<InvoiceHistoryService>().add(
          StoreInvoice.fromManual(
            date: _date,
            total: total,
            payment:
                _isPaid ? InvoicePayment.cash : InvoicePayment.credit,
            customerPhone: phone,
            customerName: name,
            customerEmail: email.isEmpty ? null : email,
            storeId: storeId,
            storeName: _storeName,
            notes: notes.isEmpty ? null : notes,
          ),
        );
      }
      await locator<SharingService>().shareReceipt(text, phone);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = _isPaid
            ? 'Paid invoice saved & sent to $phone'
            : 'Credit invoice saved & sent to $phone';
        _totalController.clear();
        _notesController.clear();
        _emailController.clear();
        // Keep name/phone for repeat invoices; reset paid default.
        _isPaid = true;
        _date = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Send failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      key: AppKeys.manualInvoiceScreen,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text(
          'Create a simple invoice when you did not use the scanner cart. '
          'Set the date and total, choose Paid or Credit, then send to the customer’s phone.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                key: AppKeys.manualInvoiceDateField,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Invoice date'),
                subtitle: Text(_dateLabel),
                trailing: TextButton(
                  onPressed: _busy ? null : _pickDate,
                  child: const Text('Change'),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PasaleTheme.radiusMd),
                  side: const BorderSide(color: PasaleTheme.hairline),
                ),
                onTap: _busy ? null : _pickDate,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: AppKeys.manualInvoiceTotalInput,
                controller: _totalController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Total price (Rs.) *',
                  hintText: 'e.g. 1500',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null) return 'Enter a valid total';
                  if (n < 0) return 'Total cannot be negative';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Autocomplete<StoreCustomer>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<StoreCustomer>.empty();
                  }
                  final query = textEditingValue.text.toLowerCase();
                  final recentCustomers = locator<InvoiceHistoryService>().recentCustomers(limit: 50);
                  return recentCustomers.where((c) =>
                      c.phone.toLowerCase().contains(query) ||
                      c.name.toLowerCase().contains(query));
                },
                displayStringForOption: (c) => c.phone,
                onSelected: (StoreCustomer c) {
                  _phoneController.text = c.phone;
                  _nameController.text = c.name;
                  if (c.email != null) _emailController.text = c.email!;
                },
                fieldViewBuilder:
                    (context, textEditingController, focusNode, onFieldSubmitted) {
                  if (_phoneController.text.isEmpty && textEditingController.text.isNotEmpty) {
                    _phoneController.text = textEditingController.text;
                  }
                  return TextFormField(
                    key: AppKeys.manualInvoicePhoneInput,
                    controller: textEditingController,
                    focusNode: focusNode,
                    enabled: !_busy,
                    onChanged: (val) {
                      _phoneController.text = val;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Customer phone *',
                      hintText: '98XXXXXXXX',
                      prefixIcon: Icon(Icons.phone_android_rounded),
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Phone required';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Customer name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: AppKeys.manualInvoiceNotesInput,
                controller: _notesController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. bulk rice order',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Text(
                'Payment',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                key: AppKeys.manualInvoicePaidCreditToggle,
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Paid'),
                    icon: Icon(Icons.check_circle_outline, size: 18),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Credit'),
                    icon: Icon(Icons.schedule, size: 18),
                  ),
                ],
                selected: {_isPaid},
                onSelectionChanged: _busy
                    ? null
                    : (s) => setState(() => _isPaid = s.first),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: AppKeys.manualInvoiceSendButton,
                onPressed: _busy ? null : _send,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_busy ? 'Sending…' : 'Send invoice'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            _status,
            key: AppKeys.statusText,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _status.toLowerCase().contains('fail') ||
                      _status.toLowerCase().contains('valid')
                  ? scheme.error
                  : scheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}
