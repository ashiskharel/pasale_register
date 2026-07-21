import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/service_locator.dart';
import '../services/session_service.dart';
import '../theme/pasale_theme.dart';

/// AppBar control: switch active substore or add a branch.
class StoreSwitcherButton extends StatefulWidget {
  const StoreSwitcherButton({
    super.key,
    this.onStoreChanged,
  });

  final VoidCallback? onStoreChanged;

  @override
  State<StoreSwitcherButton> createState() => _StoreSwitcherButtonState();
}

class _StoreSwitcherButtonState extends State<StoreSwitcherButton> {
  final _session = SessionService();
  List<Map<String, dynamic>> _stores = [];
  String? _activeId;
  String? _activeName;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final s = await _session.load();
    if (!mounted) return;
    
    // Always ensure the active store is in the list initially
    setState(() {
      _activeId = s.storeId;
      _activeName = s.storeName;
      
      final currentList = List<Map<String, dynamic>>.from(_stores);
      if (_activeId != null && _activeId!.isNotEmpty) {
        final hasActive = currentList.any((e) => e['storeId'] == _activeId);
        if (!hasActive) {
          currentList.insert(0, {
            'storeId': _activeId,
            'name': _activeName ?? _activeId,
          });
          _stores = currentList;
        }
      }
    });

    final uid = s.uid;
    if (uid == null ||
        uid.isEmpty ||
        !locator.isRegistered<FirestoreService>()) {
      return;
    }
    
    setState(() => _loading = true);
    try {
      final list =
          await locator<FirestoreService>().listMemberStores(uid: uid);
      if (!mounted) return;
      setState(() {
        _loading = false;
        
        if (_activeId != null && _activeId!.isNotEmpty) {
          final hasActive = list.any((e) => e['storeId'] == _activeId);
          if (!hasActive) {
            list.insert(0, {
              'storeId': _activeId,
              'name': _activeName ?? _activeId,
            });
          }
        }
        
        _stores = list;

        if ((_activeName == null || _activeName!.isEmpty) &&
            _activeId != null) {
          final match = list.where((e) => e['storeId'] == _activeId);
          if (match.isNotEmpty) {
            _activeName = match.first['name'] as String? ?? _activeId;
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _switchTo(Map<String, dynamic> store) async {
    final id = store['storeId'] as String? ?? '';
    if (id.isEmpty) return;
    final name = store['name'] as String? ?? id;
    final businessId = store['businessId'] as String?;
    await _session.setActiveStore(
      storeId: id,
      storeName: name,
      businessId: businessId,
    );
    if (!mounted) return;
    setState(() {
      _activeId = id;
      _activeName = name;
    });
    widget.onStoreChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Switched to $name')),
    );
  }

  Future<void> _addBranch() async {
    var s = await _session.load();
    if (s.uid == null || s.uid!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in required to add a branch')),
      );
      return;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const _AddBranchDialog(),
    );

    if (result == null || !mounted) {
      return;
    }

    final storeId = result['id']!;
    final storeName = result['name']!;

    try {
      // Ensure demo OTP sessions have Firebase Auth before multi-branch writes.
      if (locator.isRegistered<AuthService>()) {
        await locator<AuthService>().ensureFirestoreAuthAligned();
        s = await _session.load();
      }
      final uid = s.uid;
      if (uid == null || uid.isEmpty) {
        throw StateError('Sign in required to add a branch');
      }
      var bid = s.businessId;
      if (bid == null || bid.isEmpty) {
        final p = await locator<FirestoreService>().ensureMembershipProfile(
          uid: uid,
          phone: s.phone,
          displayName: s.displayName,
        );
        bid = p.businessId;
        await _session.setBusinessId(bid);
      }
      await locator<FirestoreService>().createBranchStore(
        storeId: storeId,
        storeName: storeName,
        ownerUid: uid,
        businessId: bid,
        ownerPhone: s.phone,
      );
      await _session.setActiveStore(
        storeId: storeId,
        storeName: storeName,
        businessId: bid,
      );
      await _reload();
      widget.onStoreChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Branch "$storeName" created')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyBranchError(e)),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  String _friendlyBranchError(Object e) {
    final raw = e.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('permission-denied') ||
        lower.contains('permission_denied')) {
      return 'Create branch failed: not signed into Firebase Auth.\n'
          'Demo OTP needs Anonymous sign-in enabled '
          '(Console → Authentication → Sign-in method → Anonymous), '
          'or enable Phone Auth and re-login.\n'
          'Then log out and sign in again with OTP 123456.';
    }
    if (lower.contains('already owned')) {
      return 'Create branch failed: that store ID is already taken. '
          'Pick a different branch store ID.';
    }
    if (lower.contains('anonymous') || lower.contains('operation-not-allowed')) {
      return 'Create branch failed: enable Anonymous (or Phone) sign-in '
          'in Firebase Console. See docs/AUTH_SETUP.md';
    }
    return 'Create branch failed: $e';
  }

  Future<void> _openSheet() async {
    await _reload();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  'Your stores / branches',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_stores.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No branches found yet. Create a store or heal membership.',
                  ),
                )
              else
                ..._stores.map((store) {
                  final id = store['storeId'] as String? ?? '';
                  final name = store['name'] as String? ?? id;
                  final selected = id == _activeId;
                  return ListTile(
                    leading: Icon(
                      selected ? Icons.store : Icons.store_outlined,
                    ),
                    title: Text(name),
                    subtitle: Text(id),
                    trailing: selected
                        ? const Icon(Icons.check, size: 20)
                        : null,
                    selected: selected,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _switchTo(store);
                    },
                  );
                }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _activeName ?? _activeId ?? 'Store';
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        onPressed: _openSheet,
        icon: const Icon(Icons.swap_horiz, size: 18),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: PasaleTheme.ink,
          side: const BorderSide(color: PasaleTheme.hairline),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}

class _AddBranchDialog extends StatefulWidget {
  const _AddBranchDialog();

  @override
  State<_AddBranchDialog> createState() => _AddBranchDialogState();
}

class _AddBranchDialogState extends State<_AddBranchDialog> {
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add branch / substore'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Creates another POS under your business. '
              'Shared catalog items will copy into the new branch.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _idCtrl,
              decoration: const InputDecoration(
                labelText: 'Branch store ID *',
                hintText: 'e.g. pokhara-01',
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Required';
                if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(t)) {
                  return 'Letters, numbers, _ - only';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Branch name *',
                hintText: 'e.g. Pokhara Branch',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, {
                'id': _idCtrl.text.trim(),
                'name': _nameCtrl.text.trim(),
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
