// lib/models/dispenser_status_model.dart
// MediSync - Dispenser status model (plain JSON)

class DispenserStatusModel {
  final String id;
  final String deviceId;
  final bool isOnline;
  final int batteryLevel;
  final int wifiSignalStrength;
  final DateTime? lastSeen;
  final List<CompartmentModel> compartments;
  final String firmwareVersion;
  final int totalDispenses;
  final bool isEmergencyMode;
  final PendingDispenseModel? pendingDispense;

  const DispenserStatusModel({
    required this.id,
    required this.deviceId,
    required this.isOnline,
    required this.batteryLevel,
    required this.wifiSignalStrength,
    this.lastSeen,
    required this.compartments,
    required this.firmwareVersion,
    required this.totalDispenses,
    this.isEmergencyMode = false,
    this.pendingDispense,
  });

  bool get isBatteryLow => batteryLevel < 20;
  bool get isStale => lastSeen == null ||
      DateTime.now().difference(lastSeen!).inMinutes >= 2;

  String get wifiQuality {
    if (!isOnline) return 'Offline';
    if (wifiSignalStrength >= -60) return 'Excellent';
    if (wifiSignalStrength >= -70) return 'Good';
    if (wifiSignalStrength >= -80) return 'Fair';
    return 'Weak';
  }

  int stockForCompartment(int n) =>
      compartments.firstWhere((c) => c.number == n,
          orElse: () => CompartmentModel(number: n, stock: 0)).stock;

  factory DispenserStatusModel.fromJson(Map<String, dynamic> j) => DispenserStatusModel(
    id:                 j['id'] ?? j['_id'] ?? '',
    deviceId:           j['deviceId'] ?? '',
    isOnline:           j['isOnline'] ?? false,
    batteryLevel:       (j['batteryLevel'] as num?)?.toInt() ?? 0,
    wifiSignalStrength: (j['wifiSignalStrength'] as num?)?.toInt() ?? -100,
    lastSeen:           j['lastSeen'] != null ? DateTime.tryParse(j['lastSeen']) : null,
    compartments:       (j['compartments'] as List<dynamic>? ?? [])
        .map((c) => CompartmentModel.fromJson(c as Map<String, dynamic>)).toList(),
    firmwareVersion:    j['firmwareVersion'] ?? '1.0.0',
    totalDispenses:     (j['totalDispenses'] as num?)?.toInt() ?? 0,
    isEmergencyMode:    j['isEmergencyMode'] ?? false,
    pendingDispense:    j['pendingDispense'] != null
        ? PendingDispenseModel.fromJson(j['pendingDispense'] as Map<String, dynamic>)
        : null,
  );

  static DispenserStatusModel get demo => DispenserStatusModel(
    id: 'demo', deviceId: 'ESP32_DEMO_001',
    isOnline: true, batteryLevel: 78, wifiSignalStrength: -62,
    lastSeen: DateTime.now().subtract(const Duration(seconds: 28)),
    compartments: [
      const CompartmentModel(number: 1, stock: 28),
      const CompartmentModel(number: 2, stock: 3),
      const CompartmentModel(number: 3, stock: 60),
      const CompartmentModel(number: 4, stock: 14),
      const CompartmentModel(number: 5, stock: 7),
      const CompartmentModel(number: 6, stock: 0),
      const CompartmentModel(number: 7, stock: 45),
    ],
    firmwareVersion: '2.1.4', totalDispenses: 342,
  );
}

class CompartmentModel {
  final int number;
  final int stock;
  final String? medicineId;
  const CompartmentModel({required this.number, required this.stock, this.medicineId});
  factory CompartmentModel.fromJson(Map<String, dynamic> j) => CompartmentModel(
    number: (j['number'] as num?)?.toInt() ?? 0,
    stock:  (j['stock']  as num?)?.toInt() ?? 0,
    medicineId: j['medicine']?.toString(),
  );
}

class PendingDispenseModel {
  final int compartmentNumber;
  final DateTime triggeredAt;
  final String triggeredBy;
  final bool isAcknowledged;
  const PendingDispenseModel({
    required this.compartmentNumber, required this.triggeredAt,
    required this.triggeredBy, this.isAcknowledged = false,
  });
  factory PendingDispenseModel.fromJson(Map<String, dynamic> j) => PendingDispenseModel(
    compartmentNumber: (j['compartmentNumber'] as num?)?.toInt() ?? 1,
    triggeredAt:       DateTime.tryParse(j['triggeredAt'] ?? '') ?? DateTime.now(),
    triggeredBy:       j['triggeredBy'] ?? 'schedule',
    isAcknowledged:    j['isAcknowledged'] ?? false,
  );
}
