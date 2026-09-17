// lib/main.dart
// MediSync - App entry point

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/connectivity_service.dart';

import 'features/auth/auth_provider.dart';
import 'features/medicines/medicines_provider.dart';
import 'features/dashboard/dashboard_provider.dart';

import 'features/auth/screens/splash_screen.dart';

/// Background FCM message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM Background] Data: ${message.data}');
  
  if (message.data['type'] == 'doseReminder') {
    final title = message.data['title'] ?? 'MediSync';
    final body = message.data['body'] ?? '';
    final doseId = message.data['doseId'] ?? message.data['medicineId'] ?? '';
    
    await NotificationService.instance.init();
    await NotificationService.instance.showInstant(
      id: message.hashCode,
      title: title,
      body: body,
      payload: doseId,
      isMedicineAlert: true,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Local notifications
  await NotificationService.instance.init();

  // ── FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ── Request FCM permission
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // ── Read persisted theme preference
  final prefs = await SharedPreferences.getInstance();
  final themeMode =
      _parseThemeMode(prefs.getString(AppConstants.prefThemeMode));

  runApp(MediSyncApp(initialThemeMode: themeMode));
}

ThemeMode _parseThemeMode(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

class MediSyncApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  const MediSyncApp({super.key, this.initialThemeMode = ThemeMode.system});

  @override
  State<MediSyncApp> createState() => _MediSyncAppState();

  /// Allow child widgets to change theme at runtime.
  static _MediSyncAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MediSyncAppState>()!;
}

class _MediSyncAppState extends State<MediSyncApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
  }

  void setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefThemeMode, mode.name);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => MedicinesProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        Provider(create: (_) => ConnectivityService.instance),
      ],
      child: _FcmHandler(
        child: MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeMode,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

/// Listens for incoming FCM messages while app is in foreground.
class _FcmHandler extends StatefulWidget {
  final Widget child;
  const _FcmHandler({required this.child});
  @override
  State<_FcmHandler> createState() => _FcmHandlerState();
}

class _FcmHandlerState extends State<_FcmHandler> {
  @override
  void initState() {
    super.initState();

    // Foreground FCM message → show local notification
    FirebaseMessaging.onMessage.listen((message) {
      final notif = message.notification;
      if (notif != null) {
        final type = message.data['type'];
        final doseId = message.data['doseId'] ?? message.data['medicineId'] ?? '';
        final payload = type == 'doseReminder' ? doseId : type;
        
        NotificationService.instance.showInstant(
          id: message.hashCode,
          title: notif.title ?? 'MediSync',
          body: notif.body ?? '',
          payload: payload,
          isMedicineAlert: type == 'doseReminder',
        );
      }
    });

    // App opened from notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] Opened from notification: ${message.data}');
      // Navigation handled in SplashScreen via getInitialMessage
    });

    // Register FCM token with backend after auth
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final authProv = context.read<AuthProvider>();
      if (authProv.isAuthenticated) {
        authProv.updateFcmToken(token);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
