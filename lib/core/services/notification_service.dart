// lib/core/services/notification_service.dart
// MediSync - Local notification service (flutter_local_notifications)

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:firebase_core/firebase_core.dart';
import 'api_service.dart';
import '../constants/app_constants.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ─── Initialise ────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // Set local timezone — change to your locale if needed
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onTapBackground,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // Request notification permissions for Android 13+
      await androidPlugin.requestNotificationsPermission();
      // Request exact alarm permission for Android 12+
      await androidPlugin.requestExactAlarmsPermission();

      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        AppConstants.notifChannelId,
        AppConstants.notifChannelName,
        description: AppConstants.notifChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ));
    }

    _initialized = true;
    debugPrint('[NotificationService] Initialised');
  }

  // ─── Notification Details ──────────────────────────────────────────────────
  NotificationDetails get _defaultDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelId,
          AppConstants.notifChannelName,
          channelDescription: AppConstants.notifChannelDesc,
          importance: Importance.max,
          priority: Priority.high,
          enableLights: true,
          enableVibration: true,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  NotificationDetails get _medicineDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelId,
          AppConstants.notifChannelName,
          channelDescription: AppConstants.notifChannelDesc,
          importance: Importance.max,
          priority: Priority.high,
          enableLights: true,
          enableVibration: true,
          playSound: true,
          icon: '@mipmap/ic_launcher',
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'action_taken',
              'Taken',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'action_snooze',
              'Snooze',
              showsUserInterface: true,
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  // ─── Show instant notification ─────────────────────────────────────────────
  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool isMedicineAlert = false,
  }) async {
    if (!_initialized) await init();
    await _plugin.show(
      id, 
      title, 
      body, 
      isMedicineAlert ? _medicineDetails : _defaultDetails, 
      payload: payload,
    );
  }

  // ─── Schedule a medicine reminder ──────────────────────────────────────────
  Future<void> scheduleMedicineReminder({
    required int id,
    required String medicineName,
    required String dosage,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (!_initialized) await init();
    if (scheduledTime.isBefore(DateTime.now())) return;

    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _plugin.zonedSchedule(
      id,
      '💊 Time for $medicineName',
      'Take your $dosage dose now',
      tzTime,
      _medicineDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
    debugPrint(
        '[NotificationService] Scheduled: $medicineName at $scheduledTime');
  }

  // ─── Cancel medicine reminders ─────────────────────────────────────────────
  Future<void> cancelMedicineReminders(String medicineId) async {
    final baseId = medicineId.hashCode.abs() % 10000;
    for (int i = 0; i < AppConstants.maxReminderTimesPerMedicine; i++) {
      await _plugin.cancel(baseId + i);
    }
    debugPrint('[NotificationService] Cancelled reminders for $medicineId');
  }

  // ─── Cancel single notification ────────────────────────────────────────────
  Future<void> cancel(int id) => _plugin.cancel(id);

  // ─── Cancel all ────────────────────────────────────────────────────────────
  Future<void> cancelAll() => _plugin.cancelAll();

  // ─── Low stock alert ──────────────────────────────────────────────────────
  Future<void> showLowStockAlert({
    required String medicineName,
    required int quantity,
  }) async {
    if (!_initialized) await init();
    final id = ('lowstock_$medicineName').hashCode.abs() % 90000 + 10000;
    await _plugin.show(
      id,
      '📦 Low Stock Alert',
      '$medicineName has only $quantity tablet${quantity == 1 ? '' : 's'} left. Please refill soon.',
      _defaultDetails,
      payload: 'lowStock',
    );
  }

  // ─── Expiry alert ─────────────────────────────────────────────────────────
  Future<void> showExpiryAlert({
    required String medicineName,
    required int daysLeft,
  }) async {
    if (!_initialized) await init();
    final id = ('expiry_$medicineName').hashCode.abs() % 90000 + 20000;
    await _plugin.show(
      id,
      '📅 Expiry Alert',
      '$medicineName expires in $daysLeft day${daysLeft == 1 ? '' : 's'}. Please renew your prescription.',
      _defaultDetails,
      payload: 'expiryAlert',
    );
  }

  // ─── Missed dose alert ─────────────────────────────────────────────────────
  Future<void> showMissedDoseAlert({
    required String medicineName,
    required String scheduledTime,
  }) async {
    if (!_initialized) await init();
    final id = ('missed_$medicineName').hashCode.abs() % 90000 + 30000;
    await _plugin.show(
      id,
      '⚠️ Missed Dose',
      'You missed your $medicineName dose scheduled at $scheduledTime.',
      _defaultDetails,
      payload: 'doseMissed',
    );
  }

  // ─── Get pending notifications ─────────────────────────────────────────────
  Future<List<PendingNotificationRequest>> getPending() =>
      _plugin.pendingNotificationRequests();

  // ─── Tap handler ──────────────────────────────────────────────────────────
  // ─── Tap handler ──────────────────────────────────────────────────────────
  static void _onTap(NotificationResponse response) async {
    debugPrint('[NotificationService] Tapped: ${response.payload} Action: ${response.actionId}');
    await _handleAction(response);
    // Navigation is handled by the app's main navigator
  }

  @pragma('vm:entry-point')
  static void _onTapBackground(NotificationResponse response) async {
    debugPrint('[NotificationService] Background tap: ${response.payload} Action: ${response.actionId}');
    await _handleAction(response);
  }

  static Future<void> _handleAction(NotificationResponse response) async {
    if (response.payload == null || response.payload!.isEmpty) return;
    final doseId = response.payload!;
    
    try {
      if (response.actionId == 'action_taken') {
        try {
          WidgetsFlutterBinding.ensureInitialized();
          if (Firebase.apps.isEmpty) {
            await Firebase.initializeApp();
          }
        } catch (_) {}
        
        await DoseApi.markTaken(doseId);
      } else if (response.actionId == 'action_snooze') {
        await DoseApi.snooze(doseId, minutes: 10);
        
        // Snooze for 10 minutes locally as a backup/reminder
        final snoozeTime = DateTime.now().add(const Duration(minutes: 10));
        
        final tzTime = tz.TZDateTime.from(snoozeTime, tz.local);
        final id = doseId.hashCode.abs() % 10000 + 99; // just an offset
        
        await NotificationService.instance._plugin.zonedSchedule(
          id,
          '💊 Snoozed: Time to take medicine',
          'Take your dose now',
          tzTime,
          NotificationService.instance._medicineDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: doseId,
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] Error handling action: $e');
    }
  }
}
