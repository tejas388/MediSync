// lib/features/analytics/screens/analytics_screen.dart
// MediSync - Analytics with adherence chart, per-medicine stats, and streaks

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic> _adherenceData = {};
  List<dynamic>        _perMedicine   = [];
  Map<String, dynamic> _streak        = {};
  int  _selectedDays = 7;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        AnalyticsApi.getAdherence(days: _selectedDays),
        AnalyticsApi.getPerMedicine(),
        AnalyticsApi.getStreak(),
      ]);
      setState(() {
        _adherenceData = results[0] as Map<String, dynamic>;
        _perMedicine   = results[1] as List<dynamic>;
        _streak        = results[2] as Map<String, dynamic>;
      });
    } catch (e) { debugPrint('[Analytics] $e'); }
    finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          PopupMenuButton<int>(
            initialValue: _selectedDays,
            onSelected: (v) { setState(() => _selectedDays = v); _load(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7,  child: Text('Last 7 days')),
              PopupMenuItem(value: 14, child: Text('Last 14 days')),
              PopupMenuItem(value: 30, child: Text('Last 30 days')),
              PopupMenuItem(value: 90, child: Text('Last 90 days')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Text('$_selectedDays days',
                    style: const TextStyle(fontFamily: 'Inter',
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const Icon(Icons.arrow_drop_down_rounded),
              ]),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  // ── Top stats ────────────────────────────────────────────
                  _OverallStats(data: _adherenceData, streak: _streak),
                  const SizedBox(height: 20),

                  // ── Bar chart ─────────────────────────────────────────────
                  _AdherenceChart(data: _adherenceData),
                  const SizedBox(height: 20),

                  // ── Per-medicine table ─────────────────────────────────────
                  _PerMedicineList(data: _perMedicine),
                  const SizedBox(height: 20),

                  // ── Streak card ────────────────────────────────────────────
                  _StreakCard(streak: _streak),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
    );
  }
}

class _OverallStats extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic> streak;
  const _OverallStats({required this.data, required this.streak});

  @override
  Widget build(BuildContext context) {
    final rate   = data['adherenceRate'] as int? ?? 0;
    final taken  = data['takenDoses']   as int? ?? 0;
    final missed = data['missedDoses']  as int? ?? 0;
    final total  = data['totalDoses']   as int? ?? 0;
    final curr   = streak['currentStreak'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        // Big ring
        SizedBox(
          width: 90, height: 90,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: rate / 100,
              strokeWidth: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            Text('$rate%', style: const TextStyle(fontFamily: 'Inter',
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Overall Adherence', style: TextStyle(fontFamily: 'Inter',
              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Row(children: [
            _MiniStat('$total', 'Total',  Colors.white70),
            const SizedBox(width: 14),
            _MiniStat('$taken', 'Taken',  Colors.greenAccent),
            const SizedBox(width: 14),
            _MiniStat('$missed','Missed', Colors.redAccent),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.local_fire_department_rounded,
                color: Colors.orangeAccent, size: 16),
            const SizedBox(width: 4),
            Text('$curr-day streak',
                style: const TextStyle(fontFamily: 'Inter',
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ])),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _MiniStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 18,
        fontWeight: FontWeight.w800, color: color)),
    Text(label, style: const TextStyle(fontFamily: 'Inter',
        fontSize: 10, color: Colors.white60)),
  ]);
}

class _AdherenceChart extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AdherenceChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final daily = (data['daily'] as List<dynamic>? ?? []);
    if (daily.isEmpty) return const SizedBox.shrink();

    final bars = daily.asMap().entries.map((e) {
      final d     = e.value as Map<String, dynamic>;
      final total = (d['total'] as num?)?.toDouble() ?? 0;
      final taken = (d['taken'] as num?)?.toDouble() ?? 0;
      return BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(
          toY: total,
          width: 18,
          borderRadius: BorderRadius.circular(5),
          color: AppColors.primaryLight,
          rodStackItems: [
            BarChartRodStackItem(0, taken, AppColors.primary),
          ],
        ),
      ]);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Daily Doses', style: TextStyle(fontFamily: 'Inter',
            fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 4),
        const Text('Blue = taken, Light = missed',
            style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                color: AppColors.textSecondaryLight)),
        const SizedBox(height: 20),
        SizedBox(
          height: 160,
          child: BarChart(BarChartData(
            barGroups: bars,
            gridData: FlGridData(show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: AppColors.borderLight, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                  if (v.toInt() >= daily.length) return const SizedBox.shrink();
                  final dateStr = (daily[v.toInt()] as Map<String, dynamic>)['date'] as String? ?? '';
                  if (dateStr.isEmpty) return const SizedBox.shrink();
                  try {
                    final d = DateTime.parse(dateStr);
                    return Text(DateFormat('d/M').format(d),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 9,
                            color: AppColors.textSecondaryLight));
                  } catch (_) { return const SizedBox.shrink(); }
                }, reservedSize: 24),
              ),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
          )),
        ),
      ]),
    );
  }
}

class _PerMedicineList extends StatelessWidget {
  final List<dynamic> data;
  const _PerMedicineList({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Per-Medicine Adherence', style: TextStyle(fontFamily: 'Inter',
            fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 4),
        const Text('Last 30 days', style: TextStyle(fontFamily: 'Inter',
            fontSize: 11, color: AppColors.textSecondaryLight)),
        const SizedBox(height: 16),
        ...data.take(8).map((item) {
          final m    = item as Map<String, dynamic>;
          final name = m['medicineName'] as String? ?? 'Unknown';
          final rate = (m['adherenceRate'] as num?)?.toInt() ?? 0;
          final color = rate >= 80 ? AppColors.success
              : rate >= 50 ? AppColors.warning : AppColors.error;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name, style: const TextStyle(fontFamily: 'Inter',
                    fontWeight: FontWeight.w600, fontSize: 13))),
                Text('$rate%', style: TextStyle(fontFamily: 'Inter',
                    fontWeight: FontWeight.w700, fontSize: 13, color: color)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rate / 100,
                  minHeight: 6,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final Map<String, dynamic> streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final curr    = streak['currentStreak']  as int? ?? 0;
    final longest = streak['longestStreak']  as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(children: [
        const Text('🔥', style: TextStyle(fontSize: 42)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Adherence Streak', style: TextStyle(fontFamily: 'Inter',
              fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          Row(children: [
            _StreakStat('$curr', 'Current streak', AppColors.primary),
            const SizedBox(width: 24),
            _StreakStat('$longest', 'Longest streak', AppColors.success),
          ]),
        ])),
      ]),
    );
  }
}

class _StreakStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StreakStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('$value days', style: TextStyle(fontFamily: 'Inter',
        fontSize: 18, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: const TextStyle(fontFamily: 'Inter',
        fontSize: 11, color: AppColors.textSecondaryLight)),
  ]);
}
