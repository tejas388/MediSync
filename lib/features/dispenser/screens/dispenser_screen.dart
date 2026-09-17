// lib/features/dispenser/screens/dispenser_screen.dart
// MediSync - Real-time ESP32 dispenser status and control panel

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/extensions/extensions.dart';
import '../../../models/dispenser_status_model.dart';

class DispenserScreen extends StatefulWidget {
  const DispenserScreen({super.key});
  @override
  State<DispenserScreen> createState() => _DispenserScreenState();
}

class _DispenserScreenState extends State<DispenserScreen> {
  DispenserStatusModel? _status;
  bool _loading = true;
  bool _dispensing = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await DispenserApi.getStatus();
      setState(() => _status = DispenserStatusModel.fromJson(data));
    } catch (_) {
      // No device linked — show placeholder
      setState(() => _status = null);
    } finally { setState(() => _loading = false); }
  }

  Future<void> _manualDispense(int compartment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dispense Medicine?'),
        content: Text('Trigger compartment C$compartment to dispense now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Dispense')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _dispensing = true);
    try {
      await DispenserApi.manualDispense(compartment);
      if (mounted) context.showSnack('✅ Dispense command sent to C$compartment');
    } catch (e) {
      if (mounted) context.showSnack('Failed: $e', isError: true);
    } finally { setState(() => _dispensing = false); }
  }

  Future<void> _linkDevice() async {
    final ctrl = TextEditingController();
    final deviceId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link ESP32 Device'),
        content: TextField(
          controller: ctrl, autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Device ID', hintText: 'e.g. ESP32_001',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Link'),
          ),
        ],
      ),
    );
    if (deviceId == null || deviceId.isEmpty || !mounted) return;
    try {
      await DispenserApi.registerDevice(deviceId);
      if (mounted) context.showSnack('✅ Device linked successfully');
      _load();
    } catch (e) {
      if (mounted) context.showSnack('Failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispenser'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _status == null
              ? _NoDevice(onLink: _linkDevice)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      // ── Status card ──────────────────────────────────────
                      _StatusCard(status: _status!),
                      const SizedBox(height: 16),

                      // ── Battery + WiFi ───────────────────────────────────
                      Row(children: [
                        Expanded(child: _MetricCard(
                          icon: Icons.battery_full_rounded,
                          label: 'Battery',
                          value: '${_status!.batteryLevel}%',
                          color: _status!.isBatteryLow ? AppColors.error : AppColors.success,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _MetricCard(
                          icon: Icons.wifi_rounded,
                          label: 'WiFi',
                          value: _status!.wifiQuality,
                          color: AppColors.primary,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _MetricCard(
                          icon: Icons.medication_rounded,
                          label: 'Dispenses',
                          value: '${_status!.totalDispenses}',
                          color: AppColors.accent,
                        )),
                      ]),
                      const SizedBox(height: 16),

                      // ── Compartments grid ────────────────────────────────
                      _CompartmentsGrid(
                        status: _status!,
                        onDispense: _dispensing ? null : _manualDispense,
                      ),
                      const SizedBox(height: 16),

                      // ── Emergency SOS ────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Row(children: [
                            Icon(Icons.emergency_rounded, color: AppColors.error, size: 18),
                            SizedBox(width: 6),
                            Text('Emergency SOS', style: TextStyle(fontFamily: 'Inter',
                                fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.error)),
                          ]),
                          const SizedBox(height: 6),
                          const Text('Dispenses from compartment 1 immediately and alerts caregivers.',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                                  color: AppColors.textSecondaryLight)),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _emergencySOS(),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white),
                              icon: const Icon(Icons.emergency_rounded),
                              label: const Text('Emergency Dispense'),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 80),
                    ]),
                  ),
                ),
    );
  }

  Future<void> _emergencySOS() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🚨 Emergency Dispense'),
        content: const Text('This will immediately dispense from compartment 1 and notify all caregivers. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await DispenserApi.emergencyDispense(1);
      if (mounted) context.showSnack('🚨 Emergency SOS triggered!', isError: true);
    } catch (e) {
      if (mounted) context.showSnack('Failed: $e', isError: true);
    }
  }
}

class _StatusCard extends StatelessWidget {
  final DispenserStatusModel status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: status.isOnline
              ? const LinearGradient(colors: [Color(0xFF0A7EA4), Color(0xFF00BFA5)])
              : LinearGradient(colors: [Colors.grey.shade600, Colors.grey.shade400]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.memory_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(status.deviceId, style: const TextStyle(fontFamily: 'Inter',
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text('Firmware v${status.firmwareVersion}',
                style: const TextStyle(fontFamily: 'Inter', color: Colors.white70, fontSize: 11)),
            if (status.lastSeen != null) ...[
              const SizedBox(height: 2),
              Text(
                status.isOnline
                    ? '🟢 Online'
                    : '🔴 Last seen ${status.lastSeen!.relativeDate}',
                style: const TextStyle(fontFamily: 'Inter',
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ])),
        ]),
      );
}

class _MetricCard extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _MetricCard({required this.icon, required this.label,
      required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 16,
              fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 10,
              color: AppColors.textSecondaryLight)),
        ]),
      );
}

class _CompartmentsGrid extends StatelessWidget {
  final DispenserStatusModel status;
  final void Function(int)? onDispense;
  const _CompartmentsGrid({required this.status, this.onDispense});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Compartments', style: TextStyle(fontFamily: 'Inter',
              fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: List.generate(7, (i) {
              final n     = i + 1;
              final stock = status.stockForCompartment(n);
              final color = AppConstants.compartmentColors[i];
              final low   = stock < 5;
              return GestureDetector(
                onTap: onDispense != null && status.isOnline
                    ? () => onDispense!(n) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: low ? AppColors.error : color.withOpacity(0.3)),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('C$n', style: TextStyle(fontFamily: 'Inter',
                        fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                    const SizedBox(height: 2),
                    Text('$stock', style: TextStyle(fontFamily: 'Inter',
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: low ? AppColors.error : color)),
                    const Text('pills', style: TextStyle(fontFamily: 'Inter',
                        fontSize: 9, color: AppColors.textSecondaryLight)),
                    if (low)
                      const Icon(Icons.warning_amber_rounded,
                          size: 12, color: AppColors.error),
                  ]),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          const Text('Tap a compartment to manually dispense',
              style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                  color: AppColors.textSecondaryLight)),
        ]),
      );
}

class _NoDevice extends StatelessWidget {
  final VoidCallback onLink;
  const _NoDevice({required this.onLink});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.memory_outlined, size: 80, color: AppColors.textTertiaryLight),
          const SizedBox(height: 16),
          const Text('No Device Linked', style: TextStyle(fontFamily: 'Inter',
              fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Link your ESP32 dispenser to get started',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                  color: AppColors.textSecondaryLight)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onLink,
            icon: const Icon(Icons.link_rounded),
            label: const Text('Link Device'),
          ),
        ]),
      );
}
