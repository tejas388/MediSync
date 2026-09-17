// lib/models/dose_record_model.dart
// MediSync - Dose record model

class DoseRecordModel {
  final String    id;
  final String    medicineId;
  final String    medicineName;
  final String    dosage;
  final DateTime  scheduledTime;
  final DateTime? takenTime;
  final String    status;           // pending | taken | missed | snoozed
  final DateTime? snoozeUntil;
  final bool      dispensedByDevice;
  final int       compartmentNumber;

  const DoseRecordModel({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.dosage,
    required this.scheduledTime,
    this.takenTime,
    required this.status,
    this.snoozeUntil,
    required this.dispensedByDevice,
    required this.compartmentNumber,
  });

  factory DoseRecordModel.fromJson(Map<String, dynamic> j) => DoseRecordModel(
    id:                 j['_id']            as String? ?? j['id']    as String? ?? '',
    medicineId:         j['medicineId']      as String? ?? '',
    medicineName:       j['medicineName']    as String? ?? '',
    dosage:             j['dosage']          as String? ?? '',
    scheduledTime:      DateTime.tryParse(j['scheduledTime'] as String? ?? '') ?? DateTime.now(),
    takenTime:          j['takenTime']    != null ? DateTime.tryParse(j['takenTime'] as String) : null,
    status:             j['status']          as String? ?? 'pending',
    snoozeUntil:        j['snoozeUntil'] != null ? DateTime.tryParse(j['snoozeUntil'] as String) : null,
    dispensedByDevice:  j['dispensedByDevice'] as bool? ?? false,
    compartmentNumber:  (j['compartmentNumber'] as num?)?.toInt() ?? 1,
  );

  bool get isTaken   => status == 'taken';
  bool get isMissed  => status == 'missed';
  bool get isSnoozed => status == 'snoozed';
  bool get isPending => status == 'pending';
}
