import 'package:flutter/foundation.dart';

import '../../models/medicine_model.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';

class MedicinesProvider extends ChangeNotifier {
  List<MedicineModel> _medicines = [];
  Map<int, String> _sharedCompartments = {};

  bool _isLoading = false;
  String? _error;

  String _search = '';
  String? _currentPatientId;

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  List<MedicineModel> get medicines => List.unmodifiable(_medicines);

  List<MedicineModel> get allMedicines {
    return _filteredMedicines;
  }

  List<MedicineModel> get activeMedicines {
    return _filteredMedicines.where(_isActive).toList();
  }

  List<MedicineModel> get lowStockMedicines {
    return _filteredMedicines.where(_isLowStock).toList();
  }

  List<MedicineModel> get expiringMedicines {
    return _filteredMedicines.where(_isExpiring).toList();
  }

  Map<int, String> get sharedCompartments =>
      Map.unmodifiable(_sharedCompartments);

  bool get isLoading => _isLoading;

  String? get error => _error;

  String get search => _search;

  String? get currentPatientId => _currentPatientId;

  List<MedicineModel> get _filteredMedicines {
    if (_search.trim().isEmpty) {
      return List<MedicineModel>.from(_medicines);
    }

    final query = _search.trim().toLowerCase();

    return _medicines.where((medicine) {
      final json = _medicineJson(medicine);

      final name = '${json['name'] ?? ''}'.toLowerCase();
      final dosage = '${json['dosage'] ?? ''}'.toLowerCase();
      final form = '${json['form'] ?? ''}'.toLowerCase();
      final notes = '${json['notes'] ?? ''}'.toLowerCase();

      return name.contains(query) ||
          dosage.contains(query) ||
          form.contains(query) ||
          notes.contains(query);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  void setSearch(String? value) {
    final next = value ?? '';

    if (_search == next) return;

    _search = next;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // LOAD MEDICINES
  // ---------------------------------------------------------------------------

  Future<void> loadMedicines({
    bool? active,
    String? patientId,
    Map<String, String>? params,
  }) async {
    if (_isLoading) return;

    if (patientId != null) {
      _currentPatientId = patientId;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final effectiveParams = <String, String>{
        if (params != null) ...params,
        if (active != null) 'active': active.toString(),
      };

      final List<dynamic> response;

      if (_currentPatientId != null) {
        response = await CaregiverApi.getPatientMedicines(
          _currentPatientId!,
        );
      } else {
        response = await MedicineApi.getAll(
          params: effectiveParams.isEmpty ? null : effectiveParams,
        );
      }

      final parsed = <MedicineModel>[];

      for (final item in response) {
        if (item is Map) {
          try {
            parsed.add(
              MedicineModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          } catch (e) {
            debugPrint(
              '[MedicinesProvider] Failed to parse medicine: $e',
            );
          }
        }
      }

      _medicines = parsed;

      try {
        _sharedCompartments = await MedicineApi.getSharedCompartments();
      } catch (e) {
        debugPrint(
          '[MedicinesProvider] shared compartments error: $e',
        );
        _sharedCompartments = {};
      }

      _checkAlerts();
    } catch (e, stackTrace) {
      _error = e.toString();

      debugPrint(
        '[MedicinesProvider] loadMedicines error: $e',
      );
      debugPrint('$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // ADD MEDICINE
  // ---------------------------------------------------------------------------

  Future<MedicineModel?> addMedicine(
    Map<String, dynamic> data, {
    String? patientId,
  }) async {
    try {
      _error = null;

      final targetPatientId = patientId ?? _currentPatientId;

      final Map<String, dynamic> result;

      if (targetPatientId != null) {
        result = await CaregiverApi.addMedicineForPatient(
          targetPatientId,
          data,
        );
      } else {
        result = await MedicineApi.create(data);
      }

      final medicine = MedicineModel.fromJson(
        Map<String, dynamic>.from(result),
      );

      _medicines.add(medicine);

      _checkAlerts();
      notifyListeners();

      return medicine;
    } catch (e, stackTrace) {
      _error = e.toString();

      debugPrint(
        '[MedicinesProvider] addMedicine error: $e',
      );
      debugPrint('$stackTrace');

      notifyListeners();

      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE MEDICINE
  // ---------------------------------------------------------------------------

  Future<MedicineModel?> updateMedicine(
    String medicineId,
    Map<String, dynamic> data, {
    String? patientId,
  }) async {
    try {
      _error = null;

      final targetPatientId = patientId ?? _currentPatientId;

      final Map<String, dynamic> result;

      if (targetPatientId != null) {
        result = await CaregiverApi.updateMedicineForPatient(
          targetPatientId,
          medicineId,
          data,
        );
      } else {
        result = await MedicineApi.update(
          medicineId,
          data,
        );
      }

      final updated = MedicineModel.fromJson(
        Map<String, dynamic>.from(result),
      );

      final index = _medicines.indexWhere(
        (medicine) => _medicineId(medicine) == medicineId,
      );

      if (index >= 0) {
        _medicines[index] = updated;
      } else {
        _medicines.add(updated);
      }

      _checkAlerts();
      notifyListeners();

      return updated;
    } catch (e, stackTrace) {
      _error = e.toString();

      debugPrint(
        '[MedicinesProvider] updateMedicine error: $e',
      );
      debugPrint('$stackTrace');

      notifyListeners();

      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE STOCK
  // ---------------------------------------------------------------------------

  Future<MedicineModel?> updateStock(
    String medicineId,
    int stock,
  ) async {
    return updateMedicine(
      medicineId,
      <String, dynamic>{
        'stock': stock,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TOGGLE ACTIVE
  // ---------------------------------------------------------------------------

  Future<MedicineModel?> toggleActive(
    String medicineId,
  ) async {
    final medicine = _findMedicine(medicineId);

    if (medicine == null) {
      _error = 'Medicine not found';
      notifyListeners();
      return null;
    }

    final json = _medicineJson(medicine);

    final currentActive = _readBool(
      json['isActive'] ?? json['active'] ?? json['is_active'],
      defaultValue: true,
    );

    return updateMedicine(
      medicineId,
      <String, dynamic>{
        'isActive': !currentActive,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // DELETE MEDICINE
  // ---------------------------------------------------------------------------

  Future<bool> deleteMedicine(
    String medicineId, {
    String? patientId,
  }) async {
    try {
      _error = null;

      final targetPatientId = patientId ?? _currentPatientId;

      if (targetPatientId != null) {
        await CaregiverApi.deleteMedicineForPatient(
          targetPatientId,
          medicineId,
        );
      } else {
        await MedicineApi.delete(medicineId);
      }

      _medicines.removeWhere(
        (medicine) => _medicineId(medicine) == medicineId,
      );

      _checkAlerts();
      notifyListeners();

      return true;
    } catch (e, stackTrace) {
      _error = e.toString();

      debugPrint(
        '[MedicinesProvider] deleteMedicine error: $e',
      );
      debugPrint('$stackTrace');

      notifyListeners();

      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // FIND MEDICINE
  // ---------------------------------------------------------------------------

  MedicineModel? getMedicineById(String medicineId) {
    return _findMedicine(medicineId);
  }

  MedicineModel? _findMedicine(String medicineId) {
    for (final medicine in _medicines) {
      if (_medicineId(medicine) == medicineId) {
        return medicine;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // MEDICINE HELPERS
  //
  // These intentionally read the model's JSON representation so this provider
  // remains compatible with the existing MedicineModel without assuming field
  // names that are not guaranteed by the screen/API layer.
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _medicineJson(MedicineModel medicine) {
    try {
      final dynamic value = medicine.toJson();

      if (value is Map<String, dynamic>) {
        return value;
      }

      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    } catch (e) {
      debugPrint(
        '[MedicinesProvider] medicine toJson error: $e',
      );
    }

    return <String, dynamic>{};
  }

  String _medicineId(MedicineModel medicine) {
    final json = _medicineJson(medicine);

    final value = json['_id'] ?? json['id'] ?? json['medicineId'] ?? json['medicine_id'];

    return value?.toString() ?? '';
  }

  bool _isActive(MedicineModel medicine) {
    final json = _medicineJson(medicine);

    return _readBool(
      json['isActive'] ?? json['active'] ?? json['is_active'],
      defaultValue: true,
    );
  }

  bool _isLowStock(MedicineModel medicine) {
    final json = _medicineJson(medicine);

    final stock = _readInt(
      json['stock'] ?? json['stockQuantity'] ?? json['quantity'],
    );

    if (stock == null) return false;

    final threshold = _readInt(
          json['lowStockThreshold'] ??
              json['low_stock_threshold'] ??
              json['minimumStock'] ??
              json['minStock'],
        ) ??
        10;

    return stock <= threshold;
  }

  bool _isExpiring(MedicineModel medicine) {
    final json = _medicineJson(medicine);

    final rawDate = json['expiryDate'] ??
        json['expiry_date'] ??
        json['expirationDate'] ??
        json['expiration_date'];

    if (rawDate == null) return false;

    DateTime? expiry;

    if (rawDate is DateTime) {
      expiry = rawDate;
    } else {
      expiry = DateTime.tryParse(rawDate.toString());
    }

    if (expiry == null) return false;

    final now = DateTime.now();
    final difference = expiry.difference(now).inDays;

    return difference >= 0 && difference <= 30;
  }

  int? _readInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    if (value is double) return value.toInt();

    return int.tryParse(value.toString());
  }

  bool _readBool(
    dynamic value, {
    required bool defaultValue,
  }) {
    if (value == null) return defaultValue;

    if (value is bool) return value;

    final stringValue = value.toString().toLowerCase();

    if (stringValue == 'true' || stringValue == '1' || stringValue == 'yes') {
      return true;
    }

    if (stringValue == 'false' || stringValue == '0' || stringValue == 'no') {
      return false;
    }

    return defaultValue;
  }

  // ---------------------------------------------------------------------------
  // ALERTS / REMINDERS
  // ---------------------------------------------------------------------------

  final Set<String> _notifiedLowStockIds = {};
  final Set<String> _notifiedExpiryIds = {};

  void _checkAlerts() {
    for (final medicine in _medicines) {
      final id = _medicineId(medicine);
      if (_isActive(medicine)) {
        // Low Stock (< 15)
        if (medicine.quantity < 15 && !_notifiedLowStockIds.contains(id)) {
          NotificationService.instance.showLowStockAlert(
            medicineName: medicine.name,
            quantity: medicine.quantity,
          );
          _notifiedLowStockIds.add(id);
        } else if (medicine.quantity >= 15) {
          _notifiedLowStockIds.remove(id);
        }

        // Expiry (<= 15 days)
        if (medicine.expiryDate != null) {
          final daysLeft = medicine.expiryDate!.difference(DateTime.now()).inDays;
          if (daysLeft >= 0 && daysLeft <= 15 && !_notifiedExpiryIds.contains(id)) {
            NotificationService.instance.showExpiryAlert(
              medicineName: medicine.name,
              daysLeft: daysLeft,
            );
            _notifiedExpiryIds.add(id);
          } else if (daysLeft > 15) {
            _notifiedExpiryIds.remove(id);
          }
        }
      }
      _scheduleReminders(medicine);
    }
  }

  Future<void> _scheduleReminders(
    MedicineModel medicine,
  ) async {
    final idStr = _medicineId(medicine);
    await NotificationService.instance.cancelMedicineReminders(idStr);

    if (!_isActive(medicine)) return;

    int baseId = idStr.hashCode.abs() % 10000;
    for (int i = 0; i < medicine.reminderTimeOfDays.length; i++) {
      final timeOfDay = medicine.reminderTimeOfDays[i];
      final now = DateTime.now();
      var scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
      await NotificationService.instance.scheduleMedicineReminder(
        id: baseId + i,
        medicineName: medicine.name,
        dosage: medicine.dosage,
        scheduledTime: scheduledTime,
        payload: idStr,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // PATIENT / STATE MANAGEMENT
  // ---------------------------------------------------------------------------

  void setCurrentPatient(String? patientId) {
    if (_currentPatientId == patientId) return;

    _currentPatientId = patientId;
    _medicines = [];
    _error = null;

    notifyListeners();
  }

  void clearMedicines() {
    _medicines = [];
    _sharedCompartments = {};
    _error = null;

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
