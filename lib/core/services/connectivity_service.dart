// lib/core/services/connectivity_service.dart
// MediSync - Network connectivity monitor

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  bool _isConnected = true;
  StreamSubscription? _subscription;

  /// Stream of connectivity state (true = online, false = offline)
  Stream<bool> get onConnectivityChanged => _controller.stream;

  bool get isConnected => _isConnected;

  Future<void> init() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isConnected = _isOnline(result);
    } catch (_) {
      _isConnected = true;
    }

    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final online = _isOnline(result);
      if (online != _isConnected) {
        _isConnected = online;
        _controller.add(online);
        debugPrint('[Connectivity] ${online ? "Online" : "Offline"}');
      }
    });
  }

  // connectivity_plus >= 5.0 returns List<ConnectivityResult>
  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
