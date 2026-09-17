// lib/core/services/biometric_service.dart
// MediSync - Biometric / fingerprint authentication service

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Returns true if the device supports biometrics and has enrolled biometrics.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isDeviceSupported) return false;
      final bios = await _auth.getAvailableBiometrics();
      return bios.isNotEmpty;
    } catch (e) {
      debugPrint('[BiometricService] isAvailable error: $e');
      return false;
    }
  }

  /// Prompts the user to authenticate with biometrics.
  /// Returns true on success, false otherwise.
  Future<bool> authenticate({
    String localizedReason = 'Authenticate to continue',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: false,   // Allow PIN fallback
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
    } catch (e) {
      debugPrint('[BiometricService] authenticate error: $e');
      return false;
    }
  }

  /// Returns the list of available biometric types (fingerprint, face, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Stops any in-progress authentication attempt.
  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
