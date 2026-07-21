import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/store_customer.dart';
import '../models/store_invoice.dart';
import '../models/store_deposit.dart';
import 'firestore_service.dart';
import 'service_locator.dart';
import 'deposit_history_service.dart';

const _prefsKey = 'storeInvoiceHistoryV1';

/// Invoice history: local cache + Firestore when production backend is active.
class InvoiceHistoryService extends ChangeNotifier {
  InvoiceHistoryService();

  final List<StoreInvoice> _invoices = [];
  final List<StoreCustomer> _customers = [];
  bool _loaded = false;
  String? _storeId;
  StreamSubscription<List<StoreInvoice>>? _invoiceSub;
  StreamSubscription<List<StoreCustomer>>? _customerSub;
  bool _streamingCustomers = false;

  List<StoreInvoice> get invoices => List.unmodifiable(_invoices);
  List<StoreCustomer> get customers => List.unmodifiable(_customers);
  bool get isLoaded => _loaded;
  String? get storeId => _storeId;

  InvoiceTotals get totals => _invoices.totals;

  Future<void> load({String? storeId}) async {
    _storeId = storeId ?? await _readStoreId();
    // Local cache first (works offline / fakes).
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    final local = raw
        .map((s) {
          try {
            return StoreInvoice.fromJson(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<StoreInvoice>()
        .toList();

    final sid = _storeId;
    if (sid != null &&
        sid.isNotEmpty &&
        locator.isRegistered<FirestoreService>()) {
      try {
        await _invoiceSub?.cancel();
        _invoiceSub = locator<FirestoreService>().streamInvoices(storeId: sid).listen((remote) {
          _mergeInvoices(local, remote);
          if (!_streamingCustomers) {
            _customers
              ..clear()
              ..addAll(_recalculateCustomers(_invoices));
          }
          notifyListeners();
        });
      } catch (e) {
        debugPrint('InvoiceHistoryService remote invoices stream error: $e');
      }
      try {
        await _customerSub?.cancel();
        _customerSub = locator<FirestoreService>().streamCustomers(storeId: sid).listen((remote) {
          _streamingCustomers = true;
          _customers
            ..clear()
            ..addAll(remote);
          notifyListeners();
        });
      } catch (e) {
        debugPrint('InvoiceHistoryService remote customers: $e');
      }
    }

    _mergeInvoices(local, []);

    if (!_streamingCustomers) {
      _customers
        ..clear()
        ..addAll(_recalculateCustomers(_invoices));
    }

    _loaded = true;
    notifyListeners();
  }

  void _mergeInvoices(List<StoreInvoice> local, List<StoreInvoice> remote) {
    final byId = <String, StoreInvoice>{};
    for (final inv in local) {
      byId[inv.id] = inv;
    }
    for (final inv in remote) {
      byId[inv.id] = inv;
    }
    _invoices
      ..clear()
      ..addAll(byId.values);
    _invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<String?> _readStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('storeId');
  }

  Future<void> add(StoreInvoice invoice) async {
    if (!_loaded) await load(storeId: invoice.storeId);
    final sid = invoice.storeId ?? _storeId ?? await _readStoreId();
    final toSave = (invoice.storeId == null || invoice.storeId!.isEmpty) &&
            sid != null
        ? StoreInvoice(
            id: invoice.id,
            createdAt: invoice.createdAt,
            total: invoice.total,
            payment: invoice.payment,
            source: invoice.source,
            customerPhone: invoice.customerPhone,
            customerName: invoice.customerName,
            customerEmail: invoice.customerEmail,
            storeId: sid,
            storeName: invoice.storeName,
            notes: invoice.notes,
            lineSummary: invoice.lineSummary,
          )
        : invoice;

    _invoices.removeWhere((e) => e.id == toSave.id);
    // Mark as pending sync locally until stream confirms it
    final pendingSave = StoreInvoice(
      id: toSave.id,
      createdAt: toSave.createdAt,
      total: toSave.total,
      payment: toSave.payment,
      source: toSave.source,
      customerPhone: toSave.customerPhone,
      customerName: toSave.customerName,
      customerEmail: toSave.customerEmail,
      storeId: toSave.storeId,
      storeName: toSave.storeName,
      notes: toSave.notes,
      lineSummary: toSave.lineSummary,
      isPendingSync: true,
    );
    _invoices.insert(0, pendingSave);
    await _persistLocal();

    if (sid != null &&
        sid.isNotEmpty &&
        locator.isRegistered<FirestoreService>()) {
      try {
        await locator<FirestoreService>()
            .saveInvoice(toSave, storeId: sid);
      } catch (e) {
        debugPrint('InvoiceHistoryService saveInvoice FS: $e');
      }
    }

    if (!_streamingCustomers) {
      _customers
        ..clear()
        ..addAll(_recalculateCustomers(_invoices));
    }
    notifyListeners();
  }

  void refreshOfflineCustomers() {
    if (!_streamingCustomers) {
      _customers
        ..clear()
        ..addAll(_recalculateCustomers(_invoices));
      notifyListeners();
    }
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _invoices.map((e) => e.toJson()).toList(),
    );
  }

  List<StoreCustomer> _recalculateCustomers(List<StoreInvoice> invoices) {
    final map = <String, StoreCustomer>{};
    final sortedInvs = List<StoreInvoice>.from(invoices)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final inv in sortedInvs) {
      final phone = inv.customerPhone?.trim();
      if (phone == null || phone.isEmpty) continue;
      final prev = map[phone];
      map[phone] = StoreCustomer(
        phone: phone,
        name: (inv.customerName?.trim().isNotEmpty == true)
            ? inv.customerName!.trim()
            : (prev?.name ?? phone),
        email: inv.customerEmail ?? prev?.email,
        creditBalance:
            (prev?.creditBalance ?? 0) + ((inv.isCredit && !inv.isVoided) ? inv.total : 0),
        lastActivityAt: inv.createdAt,
        transactionCount: (prev?.transactionCount ?? 0) + 1,
      );
    }
    
    if (locator.isRegistered<DepositHistoryService>()) {
      final deposits = locator<DepositHistoryService>().deposits;
      final sortedDeps = List<StoreDeposit>.from(deposits)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final dep in sortedDeps) {
        final phone = dep.customerPhone.trim();
        if (phone.isEmpty) continue;
        final prev = map[phone];
        final newDate = (prev?.lastActivityAt == null || dep.createdAt.isAfter(prev!.lastActivityAt!)) 
            ? dep.createdAt 
            : prev.lastActivityAt;
        map[phone] = StoreCustomer(
          phone: phone,
          name: (dep.customerName?.trim().isNotEmpty == true)
              ? dep.customerName!.trim()
              : (prev?.name ?? phone),
          email: prev?.email,
          creditBalance: (prev?.creditBalance ?? 0) - (dep.isVoided ? 0 : dep.amount),
          lastActivityAt: newDate,
          transactionCount: (prev?.transactionCount ?? 0) + 1,
        );
      }
    }

    final list = map.values.toList()
      ..sort((a, b) {
        final aa = a.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bb = b.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bb.compareTo(aa);
      });
    return list;
  }

  /// Recent customers (max [limit]), optionally filtered by query.
  List<StoreCustomer> recentCustomers({int limit = 10, String query = ''}) {
    final q = query.trim().toLowerCase();
    Iterable<StoreCustomer> list = _customers;
    if (q.isNotEmpty) {
      list = list.where(
        (c) =>
            c.name.toLowerCase().contains(q) ||
            c.phone.contains(q) ||
            (c.email?.toLowerCase().contains(q) ?? false),
      );
    }
    return list.take(limit).toList();
  }

  List<StoreInvoice> transactionsForPhone(String phone, {int limit = 10}) {
    return _invoices.forPhone(phone).take(limit).toList();
  }

  List<StoreInvoice> invoicesInPeriod(DateTime start, DateTime end) {
    return _invoices.inPeriod(start, end);
  }

  Future<void> clearAll() async {
    _invoices.clear();
    _customers.clear();
    await _persistLocal();
    notifyListeners();
  }

  @override
  void dispose() {
    _invoiceSub?.cancel();
    _customerSub?.cancel();
    super.dispose();
  }
}
