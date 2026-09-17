// lib/core/constants/app_colors.dart
// MediSync - Design system colour palette

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Brand ────────────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF0A7EA4);
  static const Color primaryLight = Color(0xFF4DB6D0);
  static const Color primaryDark  = Color(0xFF005F7A);
  static const Color accent       = Color(0xFF00BFA5);

  // ─── Semantic ─────────────────────────────────────────────────────────────
  static const Color success     = Color(0xFF4CAF50);
  static const Color warning     = Color(0xFFFF9800);
  static const Color warningDark = Color(0xFFE65100);
  static const Color warningLight= Color(0xFFFFF3E0);
  static const Color error       = Color(0xFFF44336);

  // ─── Backgrounds ─────────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundDark  = Color(0xFF0F1117);
  static const Color surfaceLight    = Color(0xFFFFFFFF);
  static const Color surfaceDark     = Color(0xFF1A1D26);
  static const Color cardLight       = Color(0xFFFFFFFF);
  static const Color cardDark        = Color(0xFF1E2230);

  // ─── Text ────────────────────────────────────────────────────────────────
  static const Color textPrimaryLight   = Color(0xFF0F172A);
  static const Color textPrimaryDark    = Color(0xFFF1F5F9);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textSecondaryDark  = Color(0xFF94A3B8);
  static const Color textTertiaryLight  = Color(0xFF94A3B8);
  static const Color textTertiaryDark   = Color(0xFF475569);

  // ─── Borders ─────────────────────────────────────────────────────────────
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark  = Color(0xFF2D3245);

  // ─── Gradients ───────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0A7EA4), Color(0xFF00BFA5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF4CAF50), Color(0xFF00BFA5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFF44336), Color(0xFFE91E63)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF7C4DFF), Color(0xFF2196F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Shadows ─────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: primary.withOpacity(0.12),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
