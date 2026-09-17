// lib/features/dashboard/widgets/home_tab.dart
// MediSync - Home tab: today's schedule, adherence ring, alerts, device status

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../auth/auth_provider.dart';
import '../../medicines/medicines_provider.dart';
import '../dashboard_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../models/dose_record_model.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final [summaryRes, dosesRes] = await Future.wait([
        AnalyticsApi.getSummary(),
        DoseApi.getToday(),
      ]);
      if (!mounted) return;
      final dash = context.read<DashboardProvider>();
      dash.updateFromSummary(summaryRes as Map<String, dynamic>);
      dash.updateTodayDoses(
        (dosesRes as List).map((j) => DoseRecordModel.fromJson(j as Map<String, dynamic>)).toList(),
      );

      // Also refresh medicines
      await context.read<MedicinesProvider>().loadMedicines(active: true);
    } catch (e) {
      debugPrint('[HomeTab] load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dash = context.watch<DashboardProvider>();
    final meds = context.watch<MedicinesProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ───────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(
                                  'Good ${_greeting()}, 👋',
                                  style: const TextStyle(color: Colors.white70, fontFamily: 'Inter', fontSize: 13),
                                ),
                                Text(
                                  auth.userProfile?.name.split(' ').first ?? 'User',
                                  style: const TextStyle(color: Colors.white, fontFamily: 'Inter',
                                      fontSize: 22, fontWeight: FontWeight.w800),
                                ),
                              ]),
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.white24,
                                child: Text(auth.userProfile?.initials ?? 'U',
                                  style: const TextStyle(color: Colors.white, fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700, fontSize: 16)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            DateFormat('EEEE, d MMMM y').format(DateTime.now()),
                            style: const TextStyle(color: Colors.white60, fontFamily: 'Inter', fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _loading
                  ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(children: [
                        const SizedBox(height: 16),

                        // ── Today's Adherence Card ─────────────────────────
                        _AdherenceCard(dash: dash),
                        const SizedBox(height: 16),

                        // ── Alerts ────────────────────────────────────────
                        if (meds.lowStockMedicines.isNotEmpty || meds.expiringMedicines.isNotEmpty)
                          _AlertsCard(meds: meds),

                        // ── Today's Schedule ──────────────────────────────
                        _SectionHeader(title: "Today's Schedule", count: dash.todayDoses.length),
                        const SizedBox(height: 8),
                        if (dash.todayDoses.isEmpty)
                          _EmptyDoses()
                        else
                          ...dash.todayDoses.map((d) => _DoseCard(dose: d, onTake: () => _markTaken(d), onSnooze: () => _snoozeDose(d))),

                        const SizedBox(height: 80),
                      ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markTaken(DoseRecordModel dose) async {
    try {
      await DoseApi.markTaken(dose.id);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _snoozeDose(DoseRecordModel dose) async {
    try {
      await DoseApi.snooze(dose.id, minutes: 10);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⏰ Snoozed for 10 minutes')));
      }
      await _loadData();
    } catch (e) { debugPrint('Snooze error: $e'); }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

class _AdherenceCard extends StatelessWidget {
  final DashboardProvider dash;
  const _AdherenceCard({required this.dash});

  @override
  Widget build(BuildContext context) {
    final pct = dash.todayAdherencePercent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Today's Adherence", style: TextStyle(color: Colors.white70,
              fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('$pct%', style: const TextStyle(color: Colors.white,
              fontFamily: 'Inter', fontSize: 36, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            _StatChip('${dash.takenTodayDoses} taken',  Colors.white),
            const SizedBox(width: 8),
            _StatChip('${dash.missedTodayDoses} missed', Colors.white60),
            const SizedBox(width: 8),
            _StatChip('${dash.pendingTodayDoses} pending', Colors.white38),
          ]),
        ])),
        SizedBox(
          width: 80, height: 80,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: dash.totalTodayDoses > 0 ? pct / 100.0 : 0,
              strokeWidth: 8, backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            Icon(pct >= 80 ? Icons.check_circle_rounded : Icons.pending_rounded,
                color: Colors.white, size: 28),
          ]),
        ),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label; final Color color;
  const _StatChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 10,
        fontWeight: FontWeight.w600, color: color)),
  );
}

class _AlertsCard extends StatelessWidget {
  final MedicinesProvider meds;
  const _AlertsCard({required this.meds});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
            SizedBox(width: 6),
            Text('Alerts', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700,
                fontSize: 13, color: AppColors.warningDark)),
          ]),
          const SizedBox(height: 8),
          ...meds.lowStockMedicines.map((m) => _AlertRow('📦 ${m.name}: only ${m.quantity} left')),
          ...meds.expiringMedicines.map((m) {
            final days = m.expiryDate!.difference(DateTime.now()).inDays;
            return _AlertRow('📅 ${m.name}: expires in $days days');
          }),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final String text;
  const _AlertRow(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(text, style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
        color: AppColors.warningDark)),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title; final int count;
  const _SectionHeader({required this.title, required this.count});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: const TextStyle(fontFamily: 'Inter',
            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
      ),
    ],
  );
}

class _EmptyDoses extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16)),
    child: const Column(children: [
      Icon(Icons.check_circle_rounded, size: 48, color: AppColors.success),
      SizedBox(height: 12),
      Text('All done for today! 🎉', style: TextStyle(fontFamily: 'Inter',
          fontWeight: FontWeight.w700, fontSize: 16)),
      SizedBox(height: 4),
      Text('No more doses scheduled today.', style: TextStyle(fontFamily: 'Inter',
          fontSize: 13, color: AppColors.textSecondaryLight)),
    ]),
  );
}

class _DoseCard extends StatelessWidget {
  final DoseRecordModel dose;
  final VoidCallback onTake;
  final VoidCallback onSnooze;
  const _DoseCard({required this.dose, required this.onTake, required this.onSnooze});

  @override
  Widget build(BuildContext context) {
    final statusColor = dose.isTaken ? AppColors.success
        : dose.isMissed ? AppColors.error
        : dose.isSnoozed ? AppColors.warning
        : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.medication_rounded, color: statusColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dose.medicineName, style: const TextStyle(fontFamily: 'Inter',
              fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 2),
          Text('${dose.dosage}  •  ${DateFormat('h:mm a').format(dose.scheduledTime)}',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondaryLight)),
        ])),
        if (dose.isPending) ...[
          IconButton(
            icon: const Icon(Icons.snooze_rounded, size: 20),
            color: AppColors.warning,
            tooltip: 'Snooze 10 min',
            onPressed: onSnooze,
          ),
          ElevatedButton(
            onPressed: onTake,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600),
            ),
            child: const Text('Take'),
          ),
        ] else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(dose.status.toUpperCase(),
                style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                    fontWeight: FontWeight.w700, color: statusColor)),
          ),
      ]),
    );
  }
}
