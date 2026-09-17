// lib/core/services/api_service.dart
// MediSync - HTTP client backed by FastAPI/PostgreSQL REST API
// Authorization: Firebase ID token injected automatically.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // ── Change to your machine's local IP when running on a physical device ──
  static String get _baseUrl => kIsWeb
      ? 'http://localhost:5001/api/v1'
      : 'http://100.79.40.75:5001/api/v1';
  static const Duration _timeout = Duration(seconds: 20);

  // ─── Auth header ────────────────────────────────────────────────────────────
  Future<Map<String, String>> _headers() async {
    // forceRefresh=false uses the cached token (refreshes automatically when
    // expired). Do NOT print the token — it is a security-sensitive credential.
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── GET ────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? params,
  }) async {
    final uri = _uri(path, params);
    debugPrint('[API] GET $uri');
    final res =
        await http.get(uri, headers: await _headers()).timeout(_timeout);
    return _parse(res);
  }

  // ─── GET bytes (PDF) ────────────────────────────────────────────────────────
  Future<Uint8List> getBytes(
    String path, {
    Map<String, String>? params,
  }) async {
    final uri = _uri(path, params);
    debugPrint('[API] GET bytes $uri');
    final res =
        await http.get(uri, headers: await _headers()).timeout(_timeout);
    if (res.statusCode >= 400) {
      throw _error(res);
    }
    return res.bodyBytes;
  }

  // ─── POST ───────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _uri(path);
    debugPrint('[API] POST $uri');
    final res = await http
        .post(uri, headers: await _headers(), body: jsonEncode(body ?? {}))
        .timeout(_timeout);
    return _parse(res);
  }

  // ─── PUT ────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _uri(path);
    debugPrint('[API] PUT $uri');
    final res = await http
        .put(uri, headers: await _headers(), body: jsonEncode(body ?? {}))
        .timeout(_timeout);
    return _parse(res);
  }

  // ─── PATCH ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _uri(path);
    debugPrint('[API] PATCH $uri');
    final res = await http
        .patch(uri, headers: await _headers(), body: jsonEncode(body ?? {}))
        .timeout(_timeout);
    return _parse(res);
  }

  // ─── DELETE ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> delete(String path) async {
    final uri = _uri(path);
    debugPrint('[API] DELETE $uri');
    final res =
        await http.delete(uri, headers: await _headers()).timeout(_timeout);
    return _parse(res);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  Uri _uri(String path, [Map<String, String>? params]) {
    final base = Uri.parse('$_baseUrl$path');
    return params != null ? base.replace(queryParameters: params) : base;
  }

  Map<String, dynamic> _parse(http.Response res) {
    debugPrint('[API] ${res.statusCode} ${res.request?.url}');
    if (res.statusCode >= 400) throw _error(res);
    if (res.body.isEmpty) return {'success': true};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Exception _error(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return Exception(body['message'] ?? 'Server error ${res.statusCode}');
    } catch (_) {
      return Exception('Server error ${res.statusCode}');
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TYPED API FACADES
// ═════════════════════════════════════════════════════════════════════════════

final _api = ApiService.instance;

// ── Medicines ─────────────────────────────────────────────────────────────────
class MedicineApi {
  static Future<List<Map<String, dynamic>>> getAll(
      {Map<String, String>? params}) async {
    final res = await _api.get('/medicines', params: params);
    return List<Map<String, dynamic>>.from(res['data'] as List? ?? []);
  }

  static Future<Map<String, dynamic>> getById(String id) async {
    final res = await _api.get('/medicines/$id');
    return res['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final res = await _api.post('/medicines', body: data);
    return res['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> data) async {
    final res = await _api.put('/medicines/$id', body: data);
    return res['data'] as Map<String, dynamic>;
  }

  static Future<void> delete(String id) => _api.delete('/medicines/$id');
  static Future<Map<int, String>> getSharedCompartments() async {
    final res = await _api.get('/medicines/shared-compartments');
    final data = res['data'] as Map<String, dynamic>? ?? {};
    return data.map((key, value) => MapEntry(int.parse(key), value as String));
  }
}

// ── Doses ─────────────────────────────────────────────────────────────────────
class DoseApi {
  static Future<List<dynamic>> getToday() async {
    final res = await _api.get('/doses/today');
    return res['data'] as List? ?? [];
  }

  static Future<List<dynamic>> getHistory({
    String? status,
    String? from,
    String? to,
    int page = 1,
    int limit = 25,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (status != null) 'status': status,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    };
    final res = await _api.get('/doses', params: params);
    return res['data'] as List? ?? [];
  }

  static Future<void> markTaken(String id) => _api.patch('/doses/$id/take');

  static Future<void> snooze(String id, {int minutes = 10}) =>
      _api.patch('/doses/$id/snooze', body: {'minutes': minutes});
}

// ── Analytics ─────────────────────────────────────────────────────────────────
class AnalyticsApi {
  static Future<Map<String, dynamic>> getSummary() async {
    final res = await _api.get('/analytics/summary');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  static Future<Map<String, dynamic>> getAdherence({int days = 7}) async {
    final res = await _api
        .get('/analytics/adherence', params: {'days': days.toString()});
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  static Future<List<dynamic>> getPerMedicine() async {
    final res = await _api.get('/analytics/per-medicine');
    return res['data'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> getStreak() async {
    final res = await _api.get('/analytics/streak');
    return res['data'] as Map<String, dynamic>? ?? {};
  }
}

// ── Dispenser ─────────────────────────────────────────────────────────────────
class DispenserApi {
  static Future<Map<String, dynamic>> getStatus() async {
    final res = await _api.get('/dispenser/status');
    return res['data'] as Map<String, dynamic>;
  }

  static Future<void> manualDispense(int compartment) => _api
      .post('/dispenser/dispense', body: {'compartmentNumber': compartment});

  static Future<void> emergencyDispense(int compartment) => _api
      .post('/dispenser/emergency', body: {'compartmentNumber': compartment});

  static Future<void> registerDevice(String deviceId) =>
      _api.post('/dispenser/register', body: {'deviceId': deviceId});
}

// ── Notifications ─────────────────────────────────────────────────────────────
class NotificationApi {
  static Future<Map<String, dynamic>> getAll({
    int page = 1,
    bool? unreadOnly,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      if (unreadOnly == true) 'unread': 'true',
    };
    return _api.get('/notifications', params: params);
  }

  static Future<void> markRead(String id) =>
      _api.patch('/notifications/$id/read');

  static Future<void> markAllRead() => _api.patch('/notifications/read-all');

  static Future<void> delete(String id) => _api.delete('/notifications/$id');
}

// ── Reports ───────────────────────────────────────────────────────────────────
class ReportApi {
  static Future<dynamic> getSummary({int days = 30}) async {
    final res =
        await _api.get('/reports/summary', params: {'days': days.toString()});
    return res['data'];
  }

  static Future<List<int>> getPdfBytes({
    required String from,
    required String to,
  }) async {
    final bytes =
        await _api.getBytes('/reports/pdf', params: {'from': from, 'to': to});
    return bytes.toList();
  }
}

// ── Caregiver ─────────────────────────────────────────────────────────────────
class CaregiverApi {
  static Future<List<dynamic>> getPatients() async {
    final res = await _api.get('/caregiver/patients');
    return res['data'] as List? ?? [];
  }

  static Future<void> linkPatient(String patientId) =>
      _api.post('/caregiver/link', body: {'patientId': patientId});

  static Future<void> unlinkPatient(String patientId) =>
      _api.delete('/caregiver/unlink/$patientId');

  static Future<List<dynamic>> getPatientMedicines(String patientId) async {
    final res = await _api.get('/caregiver/patients/$patientId/medicines');
    return res['data'] as List? ?? [];
  }

  static Future<List<dynamic>> getPatientDoses(String patientId,
      {String? from, String? to}) async {
    final params = <String, String>{
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    };
    final res = await _api.get('/caregiver/patients/$patientId/doses',
        params: params.isEmpty ? null : params);
    return res['data'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> addMedicineForPatient(
      String patientId, Map<String, dynamic> data) async {
    final res =
        await _api.post('/caregiver/patients/$patientId/medicines', body: data);
    return res['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateMedicineForPatient(
      String patientId, String medicineId, Map<String, dynamic> data) async {
    final res = await _api.put(
        '/caregiver/patients/$patientId/medicines/$medicineId',
        body: data);
    return res['data'] as Map<String, dynamic>;
  }

  static Future<void> deleteMedicineForPatient(
          String patientId, String medicineId) =>
      _api.delete('/caregiver/patients/$patientId/medicines/$medicineId');
}
