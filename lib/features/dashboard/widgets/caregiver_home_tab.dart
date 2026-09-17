// lib/features/dashboard/widgets/caregiver_home_tab.dart
// MediSync - Caregiver Home Tab: patient overview, alerts, upcoming doses

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../auth/auth_provider.dart';
import '../../medicines/medicines_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/extensions/extensions.dart';

class CaregiverHomeTab extends StatefulWidget {
  const CaregiverHomeTab({super.key});
  @override
  State<CaregiverHomeTab> createState() => _CaregiverHomeTabState();
}

class _CaregiverHomeTabState extends State<CaregiverHomeTab> {
  List<Map<String, dynamic>> _patients        = [];
  List<Map<String, dynamic>> _upcomingDoses   = [];
  List<Map<String, dynamic>> _alerts          = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final patientsRes = await ApiService.instance.get('/caregiver/patients');
      final rawPatients = (patientsRes['data'] as List? ?? [])
          .map((p) => p as Map<String, dynamic>).toList();

      // For each patient load today's doses and adherence
      final enriched = <Map<String, dynamic>>[];
      final allUpcoming = <Map<String, dynamic>>[];
      final allAlerts   = <Map<String, dynamic>>[];

      for (final p in rawPatients) {
        final pid = p['id'] as String? ?? '';
        try {
          final results = await Future.wait([
            ApiService.instance.get(
              '/caregiver/patients/$pid/doses',
              params: {'from': DateFormat('yyyy-MM-dd').format(DateTime.now())},
            ),
            ApiService.instance.get('/caregiver/patients/$pid/medicines'),
          ]);

          final doses    = (results[0]['data'] as List? ?? []).cast<Map<String, dynamic>>();
          final meds     = (results[1]['data'] as List? ?? []).cast<Map<String, dynamic>>();
          final taken    = doses.where((d) => d['status'] == 'taken').length;
          final total    = doses.length;
          final adherence = total > 0 ? ((taken / total) * 100).round() : 0;
          final missed   = doses.where((d) => d['status'] == 'missed').toList();
          final pending  = doses.where((d) => d['status'] == 'pending').toList();
          final lowStock = meds.where((m) => (m['isLowStock'] ?? false) == true).toList();

          enriched.add({
            ...p,
            'adherence': adherence,
            'totalMeds': meds.length,
            'missedToday': missed.length,
            'pendingToday': pending.length,
          });

          // Build upcoming list
          for (final d in pending.take(3)) {
            allUpcoming.add({...d, 'patientName': p['name'] ?? 'Patient'});
          }

          // Build alerts
          for (final d in missed) {
            allAlerts.add({
              'type': 'missed',
              'icon': Icons.warning_amber_rounded,
              'color': Colors.red,
              'title': '${p['name']}: Missed Dose',
              'body': '${d['medicineName']} was missed at ${_formatTime(d['scheduledTime'])}',
            });
          }
          for (final m in lowStock) {
            allAlerts.add({
              'type': 'lowStock',
              'icon': Icons.inventory_2_outlined,
              'color': Colors.orange,
              'title': '${p['name']}: Low Stock',
              'body': '${m['name']} has only ${m['quantity']} doses left',
            });
          }
        } catch (_) {
          enriched.add({...p, 'adherence': 0, 'totalMeds': 0, 'missedToday': 0, 'pendingToday': 0});
        }
      }

      if (mounted) {
        setState(() {
          _patients      = enriched;
          _upcomingDoses = allUpcoming;
          _alerts        = allAlerts;
        });
      }
    } catch (e) {
      debugPrint('[CaregiverHomeTab] load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatTime(dynamic isoTime) {
    if (isoTime == null) return '--';
    try {
      return DateFormat('hh:mm a').format(DateTime.parse(isoTime.toString()).toLocal());
    } catch (_) {
      return '--';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.userProfile?.name.split(' ').first ?? 'Caregiver';
    final now  = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 140,
              floating: true,
              snap: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Good ${_greeting()}, $name 👋',
                        style: const TextStyle(fontFamily: 'Inter',
                            fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(now, style: const TextStyle(
                          fontFamily: 'Inter', fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                ),
              ],
            ),

            // ── Body ───────────────────────────────────────────────────────
            _loading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()))
                : SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 16),

                      // ── Summary Cards ─────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          _SummaryCard(
                            label: 'Patients',
                            value: '${_patients.length}',
                            icon: Icons.people_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          _SummaryCard(
                            label: "Today's Alerts",
                            value: '${_alerts.length}',
                            icon: Icons.warning_amber_rounded,
                            color: _alerts.isEmpty ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 12),
                          _SummaryCard(
                            label: 'Upcoming',
                            value: '${_upcomingDoses.length}',
                            icon: Icons.schedule_rounded,
                            color: Colors.orange,
                          ),
                        ]),
                      ),

                      // ── Alerts ────────────────────────────────────────────
                      if (_alerts.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('⚠️  Alerts',
                            style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 10),
                        ..._alerts.take(5).map((a) => _AlertTile(alert: a)),
                      ],

                      // ── Upcoming Doses ────────────────────────────────────
                      if (_upcomingDoses.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('⏰  Upcoming Doses',
                            style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 10),
                        ..._upcomingDoses.map((d) => _UpcomingDoseTile(
                          dose: d,
                          onTaken: () async {
                            try {
                              await DoseApi.markTaken(d['id']);
                              if (mounted) {
                                // Reload dashboard data
                                _load();
                                // Optional: reload medicines if caregiver is viewing them
                                context.read<MedicinesProvider>().loadMedicines(active: true);
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to mark as taken: $e')),
                                );
                              }
                            }
                          },
                        )),
                      ],

                      // ── Patient Overview Cards ────────────────────────────
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('👥  My Patients',
                          style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 10),
                      if (_patients.isEmpty)
                        _EmptyPatients()
                      else
                        ..._patients.map((p) => _PatientOverviewCard(patient: p)),

                      const SizedBox(height: 80),
                    ]),
                  ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String  label;
  final String  value;
  final IconData icon;
  final Color   color;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 20,
            fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 10,
            color: color.withOpacity(0.8), fontWeight: FontWeight.w500),
          textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _AlertTile extends StatelessWidget {
  final Map<String, dynamic> alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = alert['color'] as Color? ?? Colors.red;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(alert['icon'] as IconData? ?? Icons.warning_rounded, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert['title'] as String? ?? '', style: TextStyle(fontFamily: 'Inter',
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            Text(alert['body'] as String? ?? '', style: const TextStyle(fontFamily: 'Inter',
                fontSize: 12, color: AppColors.textSecondaryLight)),
          ],
        )),
      ]),
    );
  }
}

class _UpcomingDoseTile extends StatelessWidget {
  final Map<String, dynamic> dose;
  final VoidCallback? onTaken;
  const _UpcomingDoseTile({required this.dose, this.onTaken});

  @override
  Widget build(BuildContext context) {
    String timeStr = '--';
    final raw = dose['scheduledTime'];
    if (raw != null) {
      try { timeStr = DateFormat('hh:mm a').format(DateTime.parse(raw.toString()).toLocal()); }
      catch (_) {}
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight.withOpacity(0.5)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dose['medicineName'] as String? ?? 'Medicine',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${dose['patientName']} · ${dose['dosage'] ?? ''}',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 11,
                  color: AppColors.textSecondaryLight)),
          ],
        )),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(timeStr, style: const TextStyle(fontFamily: 'Inter',
                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
            if (onTaken != null) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: onTaken,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: const Text('Taken', style: TextStyle(
                    fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success
                  )),
                ),
              ),
            ],
          ]
        ),
      ]),
    );
  }
}

class _PatientOverviewCard extends StatelessWidget {
  final Map<String, dynamic> patient;
  const _PatientOverviewCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    final adherence = patient['adherence'] as int? ?? 0;
    final missed    = patient['missedToday'] as int? ?? 0;
    final meds      = patient['totalMeds'] as int? ?? 0;
    final Color adherenceColor = adherence >= 80
        ? Colors.green : adherence >= 50 ? Colors.orange : Colors.red;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        // Avatar
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: Text(
            (patient['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
            style: const TextStyle(fontFamily: 'Inter', fontSize: 18,
                fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(patient['name'] as String? ?? 'Patient',
              style: const TextStyle(fontFamily: 'Inter',
                  fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('$meds medicines · ${missed > 0 ? "$missed missed today" : "All on track"}',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                  color: missed > 0 ? Colors.red : AppColors.textSecondaryLight)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$adherence%', style: TextStyle(fontFamily: 'Inter',
              fontSize: 18, fontWeight: FontWeight.w800, color: adherenceColor)),
          const Text('adherence', style: TextStyle(fontFamily: 'Inter',
              fontSize: 10, color: AppColors.textSecondaryLight)),
        ]),
      ]),
    );
  }
}

class _EmptyPatients extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Column(children: [
        Icon(Icons.people_outline_rounded, size: 48, color: AppColors.primary.withOpacity(0.5)),
        const SizedBox(height: 12),
        const Text('No patients yet', style: TextStyle(fontFamily: 'Inter',
            fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('Go to the Patients tab to add or link a patient.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Inter', fontSize: 13,
              color: AppColors.textSecondaryLight)),
      ]),
    ),
  );
}
