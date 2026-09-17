// lib/models/medicine_model.dart
// MediSync - Medicine model (pure JSON, no Firestore)

import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

class MedicineModel {
  final String     id;
  final String     name;
  final String     dosage;
  final int        quantity;
  final List<String> reminderTimes;   // ["08:00", "20:00"]
  final DateTime   startDate;
  final DateTime?  endDate;
  final DateTime?  expiryDate;
  final int        compartmentNumber;
  final String     foodInstruction;
  final String?    notes;
  final bool       isActive;
  final String     color;            // "#0A7EA4"
  final DateTime   createdAt;

  const MedicineModel({
    required this.id,
    required this.name,
    required this.dosage,
    required this.quantity,
    required this.reminderTimes,
    required this.startDate,
    this.endDate,
    this.expiryDate,
    required this.compartmentNumber,
    required this.foodInstruction,
    this.notes,
    required this.isActive,
    required this.color,
    required this.createdAt,
  });

  factory MedicineModel.fromJson(Map<String, dynamic> j) => MedicineModel(
    id:                 j['_id'] as String? ?? j['id'] as String? ?? '',
    name:               j['name']               as String? ?? '',
    dosage:             j['dosage']             as String? ?? '',
    quantity:           (j['quantity']           as num?)?.toInt() ?? 0,
    reminderTimes:      List<String>.from(j['reminderTimes'] as List? ?? []),
    startDate:          DateTime.tryParse(j['startDate'] as String? ?? '') ?? DateTime.now(),
    endDate:            j['endDate']   != null ? DateTime.tryParse(j['endDate']   as String) : null,
    expiryDate:         j['expiryDate']!= null ? DateTime.tryParse(j['expiryDate'] as String) : null,
    compartmentNumber:  (j['compartmentNumber'] as num?)?.toInt() ?? 1,
    foodInstruction:    j['foodInstruction']    as String? ?? 'No restriction',
    notes:              j['notes']              as String?,
    isActive:           j['isActive']           as bool? ?? true,
    color:              j['color']              as String? ?? '#0A7EA4',
    createdAt:          DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    '_id':               id,
    'name':              name,
    'dosage':            dosage,
    'quantity':          quantity,
    'reminderTimes':     reminderTimes,
    'startDate':         startDate.toIso8601String(),
    'endDate':           endDate?.toIso8601String(),
    'expiryDate':        expiryDate?.toIso8601String(),
    'compartmentNumber': compartmentNumber,
    'foodInstruction':   foodInstruction,
    'notes':             notes,
    'isActive':          isActive,
    'color':             color,
    'createdAt':         createdAt.toIso8601String(),
  };

  MedicineModel copyWith({
    String?       id,
    String?       name,
    String?       dosage,
    int?          quantity,
    List<String>? reminderTimes,
    DateTime?     startDate,
    DateTime?     endDate,
    DateTime?     expiryDate,
    int?          compartmentNumber,
    String?       foodInstruction,
    String?       notes,
    bool?         isActive,
    String?       color,
    DateTime?     createdAt,
  }) => MedicineModel(
    id:                 id                ?? this.id,
    name:               name              ?? this.name,
    dosage:             dosage            ?? this.dosage,
    quantity:           quantity          ?? this.quantity,
    reminderTimes:      reminderTimes     ?? this.reminderTimes,
    startDate:          startDate         ?? this.startDate,
    endDate:            endDate           ?? this.endDate,
    expiryDate:         expiryDate        ?? this.expiryDate,
    compartmentNumber:  compartmentNumber ?? this.compartmentNumber,
    foodInstruction:    foodInstruction   ?? this.foodInstruction,
    notes:              notes             ?? this.notes,
    isActive:           isActive          ?? this.isActive,
    color:              color             ?? this.color,
    createdAt:          createdAt         ?? this.createdAt,
  );

  // ── Computed properties ─────────────────────────────────────────────────────
  bool get isLowStock    => quantity <= AppConstants.lowStockThreshold;
  bool get isExpired     => expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysLeft = expiryDate!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 30;
  }

  List<TimeOfDay> get reminderTimeOfDays => reminderTimes.map((t) {
    final parts = t.split(':');
    return TimeOfDay(
      hour:   int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }).toList();
}
