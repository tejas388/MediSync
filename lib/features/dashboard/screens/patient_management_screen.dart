// lib/features/dashboard/screens/patient_management_screen.dart
// MediSync - Patient Management: create, link, view, and unlink patients

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/extensions/extensions.dart';
import '../../medicines/screens/medicines_screen.dart';
import '../../history/screens/history_screen.dart';

class PatientManagementScreen extends StatefulWidget {
  const PatientManagementScreen({super.key});
  @override
  State<PatientManagementScreen> createState() => _PatientManagementScreenState();
}

class _PatientManagementScreenState extends State<PatientManagementScreen> {
  List<Map<String, dynamic>> _patients = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.instance.get('/caregiver/patients');
      final list = (res['data'] as List? ?? [])
          .map((p) => p as Map<String, dynamic>).toList();
      if (mounted) setState(() => _patients = list);
    } catch (e) {
      debugPrint('[PatientMgmt] load error: $e');
      if (mounted) context.showSnack('Failed to load patients', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Create a new patient directly ─────────────────────────────────────────
  Future<void> _createPatient() async {
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey   = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Patient'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Enter the patient's details to add them to your care list.",
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Patient Name *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ApiService.instance.post('/caregiver/patients/create', body: {
        'name':  nameCtrl.text.trim(),
        if (phoneCtrl.text.trim().isNotEmpty) 'phoneNumber': phoneCtrl.text.trim(),
        if (emailCtrl.text.trim().isNotEmpty) 'email': emailCtrl.text.trim(),
      });
      if (mounted) context.showSnack('Patient created successfully ✅');
      _load();
    } catch (e) {
      if (mounted) context.showSnack('$e', isError: true);
    }
  }

  // ── Link patient by code ──────────────────────────────────────────────────
  Future<void> _linkPatient() async {
    final ctrl = TextEditingController();

    final patientCode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link Existing Patient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the MediSync Patient ID to link an existing patient account.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'MediSync Patient ID',
                hintText: 'e.g. MED-7A3F21',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().toUpperCase()),
            child: const Text('Link'),
          ),
        ],
      ),
    );

    if (patientCode == null || patientCode.isEmpty || !mounted) return;

    try {
      await ApiService.instance.post('/caregiver/link', body: {'patientCode': patientCode});
      if (mounted) context.showSnack('Patient linked successfully ✅');
      _load();
    } catch (e) {
      if (mounted) context.showSnack('$e', isError: true);
    }
  }

  // ── Unlink patient ────────────────────────────────────────────────────────
  Future<void> _unlinkPatient(Map<String, dynamic> patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Patient'),
        content: Text(
            'Are you sure you want to unlink "${patient['name']}"? '
            'Their data will remain but you will no longer manage them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.instance.delete('/caregiver/unlink/${patient['id']}');
      if (mounted) context.showSnack('Patient unlinked');
      _load();
    } catch (e) {
      if (mounted) context.showSnack('$e', isError: true);
    }
  }

  // ── Show patient detail bottom sheet ─────────────────────────────────────
  void _showPatientDetail(Map<String, dynamic> patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _PatientDetailSheet(patient: patient),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Patients'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'create_patient',
            onPressed: _createPatient,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('New Patient'),
            backgroundColor: AppColors.primary,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'link_patient',
            onPressed: _linkPatient,
            tooltip: 'Link by Patient ID',
            backgroundColor: AppColors.primary.withOpacity(0.85),
            child: const Icon(Icons.link_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _patients.isEmpty
              ? _EmptyState(onAdd: _createPatient, onLink: _linkPatient)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    itemCount: _patients.length,
                    itemBuilder: (_, i) {
                      final p = _patients[i];
                      return _PatientCard(
                        patient: p,
                        onTap:    () => _showPatientDetail(p),
                        onUnlink: () => _unlinkPatient(p),
                      );
                    },
                  ),
                ),
    );
  }
}

// ── Patient Card ─────────────────────────────────────────────────────────────
class _PatientCard extends StatelessWidget {
  final Map<String, dynamic> patient;
  final VoidCallback onTap;
  final VoidCallback onUnlink;
  const _PatientCard({required this.patient, required this.onTap, required this.onUnlink});

  @override
  Widget build(BuildContext context) {
    final name  = patient['name'] as String? ?? 'Patient';
    final phone = patient['phoneNumber'] as String?;
    final code  = patient['patientCode'] as String?;

    return Dismissible(
      key: Key(patient['id'] as String? ?? name),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onUnlink();
        return false; // Let _unlinkPatient handle the UI update
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.link_off_rounded, color: Colors.red),
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderLight.withOpacity(0.5)),
        ),
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onTap: onTap,
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 20,
                  fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
          ),
          title: Text(name, style: const TextStyle(fontFamily: 'Inter',
              fontSize: 15, fontWeight: FontWeight.w700)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (phone != null && phone.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(phone, style: const TextStyle(fontSize: 12,
                    color: AppColors.textSecondaryLight)),
              ],
              if (code != null && code.isNotEmpty) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Patient ID copied'), duration: Duration(seconds: 2)));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(code, style: const TextStyle(fontFamily: 'Inter',
                        fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ),
              ],
              if (patient['activeMedicines'] != null && (patient['activeMedicines'] as List).isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: (patient['activeMedicines'] as List).map((m) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Text(
                        '💊 ${m['name']} (C${m['compartmentNumber']})',
                        style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondaryLight),
        ),
      ),
    );
  }
}

// ── Patient Detail Bottom Sheet ───────────────────────────────────────────────
class _PatientDetailSheet extends StatelessWidget {
  final Map<String, dynamic> patient;
  const _PatientDetailSheet({required this.patient});

  @override
  Widget build(BuildContext context) {
    final name = patient['name'] as String? ?? 'Patient';
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),

          // Header
          Row(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Text(name.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 24,
                    fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontFamily: 'Inter',
                    fontSize: 18, fontWeight: FontWeight.w800)),
                if ((patient['patientCode'] as String?) != null)
                  Text(patient['patientCode'] as String,
                    style: const TextStyle(fontSize: 12,
                        color: AppColors.textSecondaryLight)),
              ],
            )),
          ]),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Quick Actions
          Text('Quick Actions', style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight)),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.medication_rounded,
            label: 'View Medicines',
            color: AppColors.primary,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => MedicinesScreen(patientId: patient['id'] as String?)));
            },
          ),
          _ActionTile(
            icon: Icons.history_rounded,
            label: 'Dose History',
            color: Colors.deepPurple,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => HistoryScreen(patientId: patient['id'] as String?)));
            },
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(radius: 20, backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, color: color, size: 20)),
    title: Text(label, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    onTap: onTap,
  );
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onLink;
  const _EmptyState({required this.onAdd, required this.onLink});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.people_outline_rounded, size: 52,
              color: AppColors.primary),
        ),
        const SizedBox(height: 20),
        const Text('No Patients Yet', style: TextStyle(fontFamily: 'Inter',
            fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Create a new patient or link an existing one using their Patient ID.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Inter', fontSize: 14,
              color: AppColors.textSecondaryLight, height: 1.5)),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Create New Patient'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onLink,
            icon: const Icon(Icons.link_rounded),
            label: const Text('Link by Patient ID'),
          ),
        ),
      ]),
    ),
  );
}
