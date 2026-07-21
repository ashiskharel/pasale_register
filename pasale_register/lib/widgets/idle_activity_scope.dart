import 'dart:async';

import 'package:flutter/material.dart';

/// Default idle duration before help "?" flashes.
const Duration kHelpIdleDuration = Duration(seconds: 30);

/// Resets an idle timer on pointer activity; reports when idle threshold is hit.
class IdleActivityScope extends StatefulWidget {
  const IdleActivityScope({
    super.key,
    required this.child,
    required this.onIdleChanged,
    this.idleDuration = kHelpIdleDuration,
  });

  final Widget child;
  final ValueChanged<bool> onIdleChanged;
  final Duration idleDuration;

  @override
  State<IdleActivityScope> createState() => _IdleActivityScopeState();
}

class _IdleActivityScopeState extends State<IdleActivityScope> {
  Timer? _timer;
  bool _idle = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(covariant IdleActivityScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idleDuration != widget.idleDuration) {
      _arm();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _arm() {
    _timer?.cancel();
    if (_idle) {
      _idle = false;
      widget.onIdleChanged(false);
    }
    _timer = Timer(widget.idleDuration, () {
      if (!mounted) return;
      _idle = true;
      widget.onIdleChanged(true);
    });
  }

  void _onActivity() {
    if (_idle || _timer != null) {
      _arm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onActivity(),
      onPointerSignal: (_) => _onActivity(),
      child: widget.child,
    );
  }
}
