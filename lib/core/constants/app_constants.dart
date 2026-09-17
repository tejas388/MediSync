// lib/core/constants/app_constants.dart
// MediSync - Global app constants

import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // ─── App Info ───────────────────────────────────────────────────────────────
  static const String appName        = 'MediSync';
  static const String appVersion     = '1.0.0';
  static const String appTagline     = 'Smart Medicine Management';

  // ─── Roles ──────────────────────────────────────────────────────────────────
  static const String rolePatient   = 'patient';
  static const String roleCaregiver = 'caregiver';

  // ─── Dispenser ──────────────────────────────────────────────────────────────
  static const int maxCompartments              = 7;
  static const int lowStockThreshold            = 5;
  static const int maxReminderTimesPerMedicine  = 6;

  // ─── SharedPreferences keys ──────────────────────────────────────────────────
  static const String prefOnboardingDone   = 'onboarding_done';
  static const String prefBiometricEnabled = 'biometric_enabled';
  static const String prefThemeMode        = 'theme_mode';
  static const String prefFcmToken         = 'fcm_token';

  // ─── Demo Mode ───────────────────────────────────────────────────────────────
  static const String demoUserId        = 'demo_patient_001';
  static const String demoUserName      = 'Arjun Sharma';
  static const String demoUserEmail     = 'arjun@demo.medisync';
  static const String demoCaregiverName = 'Dr. Priya Sharma';
  static const String demoCaregiverEmail= 'priya@demo.medisync';
  static const String demoDeviceId      = 'ESP32_DEMO_001';

  // ─── Food instructions ────────────────────────────────────────────────────────
  static const List<String> foodInstructions = [
    'Before meals',
    'After meals',
    'With meals',
    'Empty stomach',
    'No restriction',
  ];

  // ─── Compartment colors ────────────────────────────────────────────────────────
  static const List<Color> compartmentColors = [
    Color(0xFF0A7EA4), // C1 - Teal blue
    Color(0xFF00BFA5), // C2 - Teal green
    Color(0xFF7C4DFF), // C3 - Purple
    Color(0xFFFF9800), // C4 - Orange
    Color(0xFFF44336), // C5 - Red
    Color(0xFF4CAF50), // C6 - Green
    Color(0xFFE91E63), // C7 - Pink
  ];

  // ─── Notification channel ─────────────────────────────────────────────────────
  static const String notifChannelId   = 'medisync_reminders';
  static const String notifChannelName = 'Medicine Reminders';
  static const String notifChannelDesc = 'Daily medicine dose reminders and alerts';

  // ─── Snooze options (minutes) ─────────────────────────────────────────────────
  static const List<int> snoozeOptions = [5, 10, 15, 30];

  // ─── Analytics periods ────────────────────────────────────────────────────────
  static const List<int> analyticsPeriods = [7, 14, 30, 90];

  // ─── Chart colors ─────────────────────────────────────────────────────────────
  static const Color chartTaken  = Color(0xFF4CAF50);
  static const Color chartMissed = Color(0xFFF44336);
  static const Color chartPending= Color(0xFFFF9800);

  // ─── Onboarding ───────────────────────────────────────────────────────────────
  static const List<_OnboardingPage> onboardingPages = [
    _OnboardingPage(
      title: 'Never Miss a Dose',
      subtitle: 'Set smart reminders for all your medicines. MediSync notifies you at exactly the right time.',
      icon: Icons.alarm_rounded,
      color: Color(0xFF0A7EA4),
    ),
    _OnboardingPage(
      title: 'IoT Dispenser',
      subtitle: 'Your ESP32-powered dispenser auto-dispenses medicine on schedule — no manual effort needed.',
      icon: Icons.memory_rounded,
      color: Color(0xFF7C4DFF),
    ),
    _OnboardingPage(
      title: 'Caregiver Support',
      subtitle: 'Family and caregivers can monitor dose adherence and get missed-dose alerts in real time.',
      icon: Icons.medical_services_rounded,
      color: Color(0xFF00BFA5),
    ),
    _OnboardingPage(
      title: 'Track Your Health',
      subtitle: 'Beautiful analytics show your adherence trends, streaks, and inventory status at a glance.',
      icon: Icons.bar_chart_rounded,
      color: Color(0xFFFF9800),
    ),
  ];
}

// Simple value class for onboarding pages (const-compatible)
class _OnboardingPage {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  const _OnboardingPage({
    required this.title, required this.subtitle,
    required this.icon,  required this.color,
  });
}

// Expose onboarding pages publicly
class OnboardingPage {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  const OnboardingPage({
    required this.title, required this.subtitle,
    required this.icon,  required this.color,
  });

  static const List<OnboardingPage> all = [
    OnboardingPage(
      title: 'Never Miss a Dose',
      subtitle: 'Set smart reminders for all your medicines. MediSync notifies you at exactly the right time.',
      icon: Icons.alarm_rounded, color: Color(0xFF0A7EA4),
    ),
    OnboardingPage(
      title: 'IoT Dispenser',
      subtitle: 'Your ESP32-powered dispenser auto-dispenses medicine on schedule — no manual effort needed.',
      icon: Icons.memory_rounded, color: Color(0xFF7C4DFF),
    ),
    OnboardingPage(
      title: 'Caregiver Support',
      subtitle: 'Family and caregivers can monitor dose adherence and get missed-dose alerts in real time.',
      icon: Icons.medical_services_rounded, color: Color(0xFF00BFA5),
    ),
    OnboardingPage(
      title: 'Track Your Health',
      subtitle: 'Beautiful analytics show your adherence trends, streaks, and inventory status at a glance.',
      icon: Icons.bar_chart_rounded, color: Color(0xFFFF9800),
    ),
  ];
}
