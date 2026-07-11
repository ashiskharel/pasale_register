import 'camera_capability.dart';
import 'camera_vision_mode.dart';

/// Superadmin-controlled camera scope: which capabilities are live for a store.
///
/// Host apps (Pasale Register, example superadmin UI) own persistence
/// (Firestore / SharedPreferences). This type is pure config + JSON so the
/// package stays POS-agnostic.
///
/// **Defaults**
/// - Free: [CameraCapability.barcodeQr] only
/// - Premium: barcode/QR + OCR + object detection + batch segmentation
///
/// Superadmin may enable/disable any capability later without an app release,
/// within whatever your backend allows for the store's [tier].
class CameraScopePolicy {
  const CameraScopePolicy({
    required this.tier,
    required this.enabled,
    this.updatedBy,
    this.updatedAt,
    this.notes,
  });

  final PlanTier tier;

  /// Explicit capability set. Superadmin edits this set.
  final Set<CameraCapability> enabled;

  /// Who last changed scope (e.g. superadmin uid / email).
  final String? updatedBy;

  final DateTime? updatedAt;

  /// Optional free-text reason (audit).
  final String? notes;

  // ---------------------------------------------------------------------------
  // Presets
  // ---------------------------------------------------------------------------

  /// Free users: barcode + QR scanner only.
  factory CameraScopePolicy.freeDefault({
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return CameraScopePolicy(
      tier: PlanTier.free,
      enabled: const {CameraCapability.barcodeQr},
      updatedBy: updatedBy,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      notes: 'Free tier default — barcode & QR',
    );
  }

  /// Premium: full vision surface including future segmentation path.
  factory CameraScopePolicy.premiumDefault({
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return CameraScopePolicy(
      tier: PlanTier.premium,
      enabled: const {
        CameraCapability.barcodeQr,
        CameraCapability.textOcr,
        CameraCapability.objectDetection,
        CameraCapability.batchSegmentation,
      },
      updatedBy: updatedBy,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      notes: 'Premium default — full camera scope',
    );
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  bool allows(CameraCapability capability) => enabled.contains(capability);

  bool allowsMode(CameraVisionMode mode) =>
      allows(capabilityForMode(mode));

  /// Vision modes the UI may offer under this policy.
  Set<CameraVisionMode> get allowedModes {
    final modes = <CameraVisionMode>{};
    for (final c in enabled) {
      modes.add(modeForCapability(c));
    }
    return modes;
  }

  /// Safe default when starting a session.
  CameraVisionMode get defaultMode {
    if (allows(CameraCapability.barcodeQr)) {
      return CameraVisionMode.barcodeQr;
    }
    final modes = allowedModes;
    if (modes.isEmpty) return CameraVisionMode.barcodeQr;
    return modes.first;
  }

  /// Premium capabilities not yet enabled — useful for upgrade banners.
  List<CameraCapability> get lockedPremiumCapabilities {
    return CameraCapability.values
        .where((c) => c.isPremiumDefault && !allows(c))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Superadmin mutations (immutable copies)
  // ---------------------------------------------------------------------------

  CameraScopePolicy copyWith({
    PlanTier? tier,
    Set<CameraCapability>? enabled,
    String? updatedBy,
    DateTime? updatedAt,
    String? notes,
  }) {
    return CameraScopePolicy(
      tier: tier ?? this.tier,
      enabled: enabled ?? this.enabled,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
    );
  }

  /// Enable or disable a single capability (superadmin toggle).
  CameraScopePolicy withCapability(
    CameraCapability capability, {
    required bool enabled,
    String? updatedBy,
  }) {
    final next = Set<CameraCapability>.from(this.enabled);
    if (enabled) {
      next.add(capability);
    } else {
      next.remove(capability);
      // Always keep at least barcode/QR if everything else is off.
      if (next.isEmpty) {
        next.add(CameraCapability.barcodeQr);
      }
    }
    return copyWith(
      enabled: next,
      updatedBy: updatedBy,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Switch plan preset while preserving superadmin overrides if [keepOverrides].
  CameraScopePolicy withTier(
    PlanTier tier, {
    bool resetToPreset = true,
    String? updatedBy,
  }) {
    if (!resetToPreset) {
      return copyWith(
        tier: tier,
        updatedBy: updatedBy,
        updatedAt: DateTime.now().toUtc(),
      );
    }
    return tier == PlanTier.premium
        ? CameraScopePolicy.premiumDefault(updatedBy: updatedBy)
        : CameraScopePolicy.freeDefault(updatedBy: updatedBy);
  }

  // ---------------------------------------------------------------------------
  // Mode ↔ capability mapping
  // ---------------------------------------------------------------------------

  static CameraCapability capabilityForMode(CameraVisionMode mode) {
    return switch (mode) {
      CameraVisionMode.barcodeQr => CameraCapability.barcodeQr,
      CameraVisionMode.text => CameraCapability.textOcr,
      CameraVisionMode.objectDetection => CameraCapability.objectDetection,
      CameraVisionMode.batchCheckout => CameraCapability.batchSegmentation,
    };
  }

  static CameraVisionMode modeForCapability(CameraCapability capability) {
    return switch (capability) {
      CameraCapability.barcodeQr => CameraVisionMode.barcodeQr,
      CameraCapability.textOcr => CameraVisionMode.text,
      CameraCapability.objectDetection => CameraVisionMode.objectDetection,
      CameraCapability.batchSegmentation => CameraVisionMode.batchCheckout,
    };
  }

  // ---------------------------------------------------------------------------
  // JSON (persist to Firestore / prefs later)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'tier': tier.name,
        'enabled': enabled.map((e) => e.name).toList()..sort(),
        if (updatedBy != null) 'updatedBy': updatedBy,
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (notes != null) 'notes': notes,
      };

  factory CameraScopePolicy.fromJson(Map<String, dynamic> json) {
    final tierName = json['tier'] as String? ?? 'free';
    final tier = PlanTier.values.firstWhere(
      (t) => t.name == tierName,
      orElse: () => PlanTier.free,
    );
    final raw = (json['enabled'] as List?)?.map((e) => e.toString()) ??
        const <String>['barcodeQr'];
    final enabled = <CameraCapability>{};
    for (final name in raw) {
      final match = CameraCapability.values.where((c) => c.name == name);
      if (match.isNotEmpty) enabled.add(match.first);
    }
    if (enabled.isEmpty) {
      enabled.add(CameraCapability.barcodeQr);
    }
    return CameraScopePolicy(
      tier: tier,
      enabled: enabled,
      updatedBy: json['updatedBy'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      notes: json['notes'] as String?,
    );
  }

  @override
  String toString() =>
      'CameraScopePolicy(tier: ${tier.name}, enabled: ${enabled.map((e) => e.name).join(',')})';
}
