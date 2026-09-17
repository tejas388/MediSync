// lib/core/extensions/extensions.dart
// MediSync - Dart extensions and global validators

import 'package:flutter/material.dart';

// ─── BuildContext extensions ───────────────────────────────────────────────────

extension ContextX on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool      get isDark    => Theme.of(this).brightness == Brightness.dark;

  void showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).clearSnackBars();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
        backgroundColor: isError ? const Color(0xFFF44336) : const Color(0xFF323232),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─── String extensions ─────────────────────────────────────────────────────────

extension StringX on String {
  /// Converts "#0A7EA4" hex string to Color
  Color get hexColor {
    final hex = replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return const Color(0xFF0A7EA4);
  }

  /// Capitalise first letter
  String get capitalised =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  bool get isValidEmail =>
      RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(this);

  bool get isStrongPassword => length >= 8;
}

// ─── TimeOfDay extensions ──────────────────────────────────────────────────────

extension TimeOfDayX on TimeOfDay {
  /// Returns "HH:mm" 24-hour string, e.g. "08:30"
  String get toHHmm =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Returns "8:30 AM" 12-hour display string
  String get display {
    final h   = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m   = minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

// ─── DateTime extensions ───────────────────────────────────────────────────────

extension DateTimeX on DateTime {
  /// "Today", "Yesterday", "Mon 14 Jul", etc.
  String get relativeDate {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date  = DateTime(year, month, day);
    final diff  = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7)  return _weekday;
    return '$day $_monthAbbr $year';
  }

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  String get _weekday {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[weekday - 1]} $day $_monthAbbr';
  }

  String get _monthAbbr {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return months[month - 1];
  }

  /// "8:30 AM"
  String get timeDisplay {
    final h    = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m    = minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

// ─── Form Validators ──────────────────────────────────────────────────────────

class Validators {
  Validators._();

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!v.trim().isValidEmail)        return 'Enter a valid email address';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty)        return 'Password is required';
    if (v.length < 8)                  return 'Password must be at least 8 characters';
    return null;
  }

  static String? confirmPassword(String? v, String password) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != password)          return 'Passwords do not match';
    return null;
  }

  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    if (v.trim().length < 2)           return 'Name must be at least 2 characters';
    return null;
  }

  static String? medicineName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Medicine name is required';
    if (v.trim().length < 2)           return 'Name is too short';
    return null;
  }

  static String? dosage(String? v) {
    if (v == null || v.trim().isEmpty) return 'Dosage is required (e.g. 500mg)';
    return null;
  }

  static String? quantity(String? v) {
    if (v == null || v.trim().isEmpty) return 'Quantity is required';
    final n = int.tryParse(v.trim());
    if (n == null || n < 0)            return 'Enter a valid positive number';
    return null;
  }

  static String? required(String? v, [String field = 'This field']) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return null;
  }
}

// ─── Color extensions ─────────────────────────────────────────────────────────

extension ColorX on Color {
  /// Converts Color to "#RRGGBB" hex string
  String get toHex {
    final r = red.toRadixString(16).padLeft(2, '0');
    final g = green.toRadixString(16).padLeft(2, '0');
    final b = blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }
}
