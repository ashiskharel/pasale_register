import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/store_deposit.dart';
import 'firestore_service.dart';
import 'service_locator.dart';
import 'invoice_history_service.dart';

const _prefsKey = 'storeDepositHistoryV1';

class DepositHistoryService extends ChangeNotifier {
  DepositHistoryService();

  final List<StoreDeposit> _deposits = [];
  bool _loaded = false;
  String? _storeId;
  StreamSubscription<List<StoreDeposit>>? _depositSub;

  List<StoreDeposit> get deposits => List.unmodifiable(_deposits);
  bool get isLoaded => _loaded;
  String? get storeId => _storeId;

  Future<void> load({String? storeId}) async {
    _storeId = storeId ?? await _readStoreId();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    final local = raw
        .map((s) {
          try {
            return StoreDeposit.fromJson(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<StoreDeposit>()
        .toList();

    final sid = _storeId;
    if (sid != null &&
        sid.isNotEmpty &&
        locator.isRegistered<FirestoreService>()) {
      try {
        await _depositSub?.cancel();
        _depositSub = locator<FirestoreService>().streamDeposits(storeId: sid).listen((remote) {
          _mergeDeposits(local, remote);
          notifyListeners();
        });
      } catch (e) {
        debugPrint('DepositHistoryService remote deposits stream error: $e');
      }
    }

    _mergeDeposits(local, []);
    _loaded = true;
    notifyListeners();
  }

  void _mergeDeposits(List<StoreDeposit> local, List<StoreDeposit> remote) {
    final byId = <String, StoreDeposit>{};
    for (final dep in local) {
      byId[dep.id] = dep;
    }
    for (final dep in remote) {
      byId[dep.id] = dep;
    }
    _deposits
      ..clear()
      ..addAll(byId.values);
    _deposits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<String?> _readStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('storeId');
  }

  Future<void> add(StoreDeposit deposit) async {
    if (!_loaded) await load(storeId: deposit.storeId);
    final sid = deposit.storeId ?? _storeId ?? await _readStoreId();
    final newId = deposit.id.isNotEmpty
        ? deposit.id
        : 'DEP_LOCAL_${DateTime.now().millisecondsSinceEpoch}';
        
    final toSave = (deposit.storeId == null || deposit.storeId!.isEmpty) &&
            sid != null
        ? StoreDeposit(
            id: newId,
            createdAt: deposit.createdAt,
            amount: deposit.amount,
            payment: deposit.payment,
            customerPhone: deposit.customerPhone,
            customerName: deposit.customerName,
            storeId: sid,
            notes: deposit.notes,
          )
        : deposit.id.isEmpty
            ? StoreDeposit(
                id: newId,
                createdAt: deposit.createdAt,
                amount: deposit.amount,
                payment: deposit.payment,
                customerPhone: deposit.customerPhone,
                customerName: deposit.customerName,
                storeId: deposit.storeId,
                notes: deposit.notes,
              )
            : deposit;

    _deposits.removeWhere((e) => e.id == toSave.id);
    final pendingSave = StoreDeposit(
      id: toSave.id,
      createdAt: toSave.createdAt,
      amount: toSave.amount,
      payment: toSave.payment,
      customerPhone: toSave.customerPhone,
      customerName: toSave.customerName,
      storeId: toSave.storeId,
      notes: toSave.notes,
      isPendingSync: true,
    );
    _deposits.insert(0, pendingSave);
    await _persistLocal();

    if (sid != null &&
        sid.isNotEmpty &&
        locator.isRegistered<FirestoreService>()) {
      try {
        await locator<FirestoreService>()
            .saveDeposit(toSave, storeId: sid);
      } catch (e) {
        debugPrint('DepositHistoryService saveDeposit FS: $e');
      }
    }
      
    if (locator.isRegistered<InvoiceHistoryService>()) {
      locator<InvoiceHistoryService>().refreshOfflineCustomers();
    }

    notifyListeners();
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _deposits.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> clearAll() async {
    _deposits.clear();
    await _persistLocal();
    notifyListeners();
  }

  @override
  void dispose() {
    _depositSub?.cancel();
    super.dispose();
  }
}
