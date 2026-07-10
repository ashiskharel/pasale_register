class Device {
  final String deviceId;
  final String model;
  final String osVersion;
  final DateTime lastActive;

  Device({
    required this.deviceId,
    required this.model,
    required this.osVersion,
    required this.lastActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'model': model,
      'osVersion': osVersion,
      'lastActive': lastActive.toIso8601String(),
    };
  }

  factory Device.fromMap(Map<String, dynamic> map, String deviceId) {
    final lastActiveRaw = map['lastActive'];
    DateTime lastActive = DateTime.now();
    if (lastActiveRaw is String) {
      lastActive = DateTime.tryParse(lastActiveRaw) ?? DateTime.now();
    } else if (lastActiveRaw is DateTime) {
      lastActive = lastActiveRaw;
    } else if (lastActiveRaw != null) {
      try {
        lastActive = (lastActiveRaw as dynamic).toDate();
      } catch (_) {}
    }
    return Device(
      deviceId: deviceId,
      model: map['model'] as String? ?? '',
      osVersion: map['osVersion'] as String? ?? '',
      lastActive: lastActive,
    );
  }
}
