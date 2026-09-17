// lib/models/notification_model.dart
// MediSync - In-app notification model (REST API version, no Firestore)

import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// All notification types used in MediSync.
enum NotificationType {
  doseReminder,
  doseMissed,
  lowStock,
  expiryAlert,
  caregiverAlert,
  deviceOffline,
  emergencySOS,
  scheduleUpdate,
}

extension NotificationTypeExt on NotificationType {
  String get icon {
    switch (this) {
      case NotificationType.doseReminder:   return '💊';
      case NotificationType.doseMissed:     return '⚠️';
      case NotificationType.lowStock:       return '📦';
      case NotificationType.expiryAlert:    return '📅';
      case NotificationType.caregiverAlert: return '👨‍⚕️';
      case NotificationType.deviceOffline:  return '📡';
      case NotificationType.emergencySOS:   return '🚨';
      case NotificationType.scheduleUpdate: return '🔔';
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.doseReminder:   return AppColors.primary;
      case NotificationType.doseMissed:     return AppColors.warning;
      case NotificationType.lowStock:       return AppColors.warning;
      case NotificationType.expiryAlert:    return AppColors.error;
      case NotificationType.caregiverAlert: return AppColors.accent;
      case NotificationType.deviceOffline:  return AppColors.textSecondaryLight;
      case NotificationType.emergencySOS:   return AppColors.error;
      case NotificationType.scheduleUpdate: return AppColors.primary;
    }
  }

  String get label {
    switch (this) {
      case NotificationType.doseReminder:   return 'Dose Reminder';
      case NotificationType.doseMissed:     return 'Missed Dose';
      case NotificationType.lowStock:       return 'Low Stock';
      case NotificationType.expiryAlert:    return 'Expiry Alert';
      case NotificationType.caregiverAlert: return 'Caregiver';
      case NotificationType.deviceOffline:  return 'Device';
      case NotificationType.emergencySOS:   return 'Emergency';
      case NotificationType.scheduleUpdate: return 'Schedule';
    }
  }
}

/// In-app notification record from REST API (PostgreSQL backend).
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;
  final String? medicineId;
  final String? medicineName;
  final DateTime createdAt;
  final Map<String, dynamic>? extra;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.medicineId,
    this.medicineName,
    required this.createdAt,
    this.extra,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> j) {
    return NotificationModel(
      id:           j['id']           as String? ?? '',
      userId:       j['userId']       as String? ?? '',
      title:        j['title']        as String? ?? '',
      body:         j['body']         as String? ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == (j['type'] as String? ?? ''),
        orElse: () => NotificationType.doseReminder,
      ),
      isRead:       j['isRead']       as bool?   ?? false,
      medicineId:   j['medicineId']   as String?,
      medicineName: j['medicineName'] as String?,
      createdAt: j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      extra: j['extra'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId':       userId,
    'title':        title,
    'body':         body,
    'type':         type.name,
    'isRead':       isRead,
    'medicineId':   medicineId,
    'medicineName': medicineName,
    'createdAt':    createdAt.toIso8601String(),
    'extra':        extra,
  };

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    id: id, userId: userId, title: title, body: body, type: type,
    isRead: isRead ?? this.isRead,
    medicineId: medicineId, medicineName: medicineName,
    createdAt: createdAt, extra: extra,
  );
}
