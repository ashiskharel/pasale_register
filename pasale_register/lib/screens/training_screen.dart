import 'package:flutter/material.dart';

import '../constants/keys.dart';
import '../models/user_role.dart';
import '../services/session_service.dart';

/// Temporary step-by-step onboarding. Requires explicit consent to start.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({
    super.key,
    required this.role,
    required this.onFinished,
  });

  final UserRole role;
  final VoidCallback onFinished;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final _session = SessionService();
  final _pageController = PageController();

  bool _consent = false;
  bool _started = false;
  int _page = 0;

  List<_TrainStep> get _steps {
    switch (widget.role) {
      case UserRole.storeOwner:
        return const [
          _TrainStep(
            title: 'Scan to sell',
            body:
                'Open Scanner to read barcodes. Items land in the cart with your store prices. Unknown codes open a quick register form with optional photo for training.',
            icon: Icons.qr_code_scanner,
          ),
          _TrainStep(
            title: 'Checkout & invoices',
            body:
                'Enter the customer phone on the subtotal. Mark Paid to finish and scan the next customer. Mark Credit to SMS a detailed bill to their number.',
            icon: Icons.receipt_long,
          ),
          _TrainStep(
            title: 'Catalog, vendors & stock',
            body:
                'Fill catalog in spare time. Use Scan Invoice for vendor bills. Manage vendors and reorder when stock runs low. Dashboard shows daily → yearly sales.',
            icon: Icons.inventory_2_outlined,
          ),
          _TrainStep(
            title: 'Premium camera tools',
            body:
                'After activating premium: OCR text, object detection, and batch checkout. Free tier covers barcode scanning.',
            icon: Icons.camera_enhance_outlined,
          ),
        ];
      case UserRole.vendor:
        return const [
          _TrainStep(
            title: 'Stores near you',
            body:
                'See partner stores, items they sell, and low-stock alerts for your area so you know who needs supply.',
            icon: Icons.store_mall_directory_outlined,
          ),
          _TrainStep(
            title: 'Chat & call',
            body:
                'Reach store owners from the menu — chat or call — to confirm orders and deliveries.',
            icon: Icons.chat_outlined,
          ),
          _TrainStep(
            title: 'Premium invoices & camera',
            body:
                'Premium: send invoices that auto-register in the store database, camera inventory tools, and accounting.',
            icon: Icons.workspace_premium_outlined,
          ),
        ];
      case UserRole.buyer:
        return const [
          _TrainStep(
            title: 'Find shops',
            body:
                'Browse stores and place orders. Track credit balance and deposits with store owners you shop with.',
            icon: Icons.shopping_bag_outlined,
          ),
          _TrainStep(
            title: 'Notifications',
            body:
                'Get chat alerts and order updates. Manage them anytime under Settings.',
            icon: Icons.notifications_outlined,
          ),
        ];
    }
  }

  Future<void> _finish() async {
    await _session.markTrainingConsent();
    widget.onFinished();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = _steps;

    return Scaffold(
      key: AppKeys.trainingScreen,
      appBar: AppBar(
        title: const Text('Quick training'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: !_started
            ? _buildConsent(theme)
            : _buildSteps(theme, steps),
      ),
    );
  }

  Widget _buildConsent(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.school_rounded,
              size: 36,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Before you begin',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'A short walkthrough shows how to use Pasale as a ${widget.role.label}. '
            'This training is temporary and can be skipped once you consent.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const Spacer(),
          Card(
            child: CheckboxListTile(
              key: AppKeys.trainingConsentCheckbox,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I agree to view this training and understand how my role works in the app.',
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            key: AppKeys.startTrainingButton,
            onPressed: _consent
                ? () => setState(() {
                      _started = true;
                      _page = 0;
                    })
                : null,
            child: const Text('Start training'),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: AppKeys.skipTrainingButton,
            onPressed: _consent ? _finish : null,
            child: const Text('Skip training (still need consent)'),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps(ThemeData theme, List<_TrainStep> steps) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_page + 1) / steps.length,
          minHeight: 4,
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: steps.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final step = steps[i];
              return Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.12),
                      child: Icon(step.icon,
                          size: 40, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Step ${i + 1} of ${steps.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      step.body,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.45,
                        color: Colors.grey.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(
            children: [
              if (_page > 0)
                TextButton(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  },
                  child: const Text('Back'),
                ),
              const Spacer(),
              if (_page < steps.length - 1)
                FilledButton(
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  },
                  child: const Text('Next'),
                )
              else
                FilledButton(
                  key: AppKeys.finishTrainingButton,
                  onPressed: _finish,
                  child: const Text('Finish & open app'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrainStep {
  const _TrainStep({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;
}
