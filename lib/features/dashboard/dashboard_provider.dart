// lib/features/dashboard/dashboard_provider.dart
// MediSync - Dashboard provider (updated for Node.js API)

import 'package:flutter/foundation.dart';
import '../../models/dose_record_model.dart';
import '../../models/dispenser_status_model.dart';

class DashboardProvider extends ChangeNotifier {
  List<DoseRecordModel>  _todayDoses  = [];
  DispenserStatusModel?  _dispenser;
  Map<String, dynamic>   _summary     = {};
  bool _isLoading = false;

  List<DoseRecordModel>  get todayDoses     => _todayDoses;
  DispenserStatusModel?  get dispenserStatus => _dispenser;
  Map<String, dynamic>   get summary        => _summary;
  bool                   get isLoading      => _isLoading;

  int get totalTodayDoses   => _todayDoses.length;
  int get takenTodayDoses   => _todayDoses.where((d) => d.isTaken).length;
  int get missedTodayDoses  => _todayDoses.where((d) => d.isMissed).length;
  int get pendingTodayDoses => _todayDoses.where((d) => d.isPending).length;

  double get todayAdherence {
    if (totalTodayDoses == 0) return 1.0;
    return takenTodayDoses / totalTodayDoses;
  }
  int get todayAdherencePercent => (todayAdherence * 100).round();

  DoseRecordModel? get nextUpcomingDose {
    final pending = _todayDoses
        .where((d) => d.isPending && d.scheduledTime.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return pending.isEmpty ? null : pending.first;
  }

  void updateTodayDoses(List<DoseRecordModel> doses) {
    _todayDoses = doses..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    notifyListeners();
  }

  void updateDispenserStatus(DispenserStatusModel? status) {
    _dispenser = status;
    notifyListeners();
  }

  void updateFromSummary(Map<String, dynamic> data) {
    _summary = data;
    notifyListeners();
  }

  void setLoading(bool v) { _isLoading = v; notifyListeners(); }
}
