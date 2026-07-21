import 'package:flutter/material.dart';

import '../constants/keys.dart';
import '../services/session_service.dart';

enum PremiumFeature { camera, accounting, invoices }

/// Pay-and-activate premium features (camera tools, accounting, invoices).
class PremiumFeaturesScreen extends StatefulWidget {
  const PremiumFeaturesScreen({
    super.key,
    this.focus,
  });

  final PremiumFeature? focus;

  @override
  State<PremiumFeaturesScreen> createState() => _PremiumFeaturesScreenState();
}

class _PremiumFeaturesScreenState extends State<PremiumFeaturesScreen> {
  final _session = SessionService();
  bool _camera = false;
  bool _accounting = false;
  bool _invoices = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _session.load();
    if (!mounted) return;
    setState(() {
      _camera = s.premiumCamera;
      _accounting = s.premiumAccounting;
      _invoices = s.premiumInvoices;
      _loading = false;
    });
  }

  Future<void> _activate(PremiumFeature feature) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activate premium'),
        content: Text(
          'Pay and activate ${_label(feature)}?\n\n'
          'Demo: no real payment — this marks the feature active on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pay & activate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    switch (feature) {
      case PremiumFeature.camera:
        await _session.setPremium(camera: true);
        setState(() => _camera = true);
        break;
      case PremiumFeature.accounting:
        await _session.setPremium(accounting: true);
        setState(() => _accounting = true);
        break;
      case PremiumFeature.invoices:
        await _session.setPremium(invoices: true);
        setState(() => _invoices = true);
        break;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_label(feature)} activated')),
    );
  }

  String _label(PremiumFeature f) {
    switch (f) {
      case PremiumFeature.camera:
        return 'Camera (OCR, object detection, batch checkout)';
      case PremiumFeature.accounting:
        return 'Accounting';
      case PremiumFeature.invoices:
        return 'Send invoices (auto-register in store DB)';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      key: AppKeys.premiumScreen,
      padding: const EdgeInsets.all(12),
      children: [
        _PremiumTile(
          title: 'Camera tools',
          subtitle: 'Text (OCR), object detection, batch checkout',
          active: _camera,
          highlighted: widget.focus == PremiumFeature.camera,
          onActivate: () => _activate(PremiumFeature.camera),
        ),
        _PremiumTile(
          title: 'Accounting',
          subtitle: 'Ledgers, P&L, and vendor payables',
          active: _accounting,
          highlighted: widget.focus == PremiumFeature.accounting,
          onActivate: () => _activate(PremiumFeature.accounting),
        ),
        _PremiumTile(
          title: 'Invoices to stores',
          subtitle: 'Auto-registers in store owner database',
          active: _invoices,
          highlighted: widget.focus == PremiumFeature.invoices,
          onActivate: () => _activate(PremiumFeature.invoices),
        ),
      ],
    );
  }
}

class _PremiumTile extends StatelessWidget {
  const _PremiumTile({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onActivate,
    this.highlighted = false,
  });

  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onActivate;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlighted ? Colors.amber.shade50 : null,
      child: ListTile(
        leading: Icon(
          active ? Icons.verified : Icons.workspace_premium_outlined,
          color: active ? Colors.green : Colors.amber.shade800,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: active
            ? Chip(
                label: const Text('Active'),
                backgroundColor: Colors.green.shade50,
              )
            : FilledButton(
                onPressed: onActivate,
                child: const Text('Pay'),
              ),
      ),
    );
  }
}
