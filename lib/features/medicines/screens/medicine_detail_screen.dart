import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medisync/features/medicines/medicines_provider.dart';
import 'package:medisync/models/medicine_model.dart';
import 'package:medisync/models/dose_record_model.dart';
import 'package:medisync/core/constants/app_colors.dart';
import 'package:medisync/core/services/api_service.dart';
import 'package:intl/intl.dart';
import 'add_edit_medicine_screen.dart';

class MedicineDetailScreen extends StatefulWidget {
  final MedicineModel medicine;

  const MedicineDetailScreen({super.key, required this.medicine});

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  bool _isLoadingHistory = true;
  List<DoseRecordModel> _doseHistory = [];
  late MedicineModel _currentMedicine;

  @override
  void initState() {
    super.initState();
    _currentMedicine = widget.medicine;
    _fetchHistory();
  }

  void _updateMedicineFromProvider() {
    final provider = context.read<MedicinesProvider>();
    final updated = provider.medicines.firstWhere(
      (m) => m.id == _currentMedicine.id,
      orElse: () => _currentMedicine,
    );
    if (mounted) {
      setState(() {
        _currentMedicine = updated;
      });
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final res = await ApiService.instance.get('/doses', params: {'medicineId': _currentMedicine.id, 'limit': '10'});
      if (res.containsKey('data')) {
        final List<dynamic> data = res['data'] as List? ?? [];
        if (mounted) {
          setState(() {
            _doseHistory = data.map((j) => DoseRecordModel.fromJson(j as Map<String, dynamic>)).toList();
            _isLoadingHistory = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _toggleActive() async {
    try {
      await context.read<MedicinesProvider>().toggleActive(_currentMedicine.id);
      _updateMedicineFromProvider();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteMedicine() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: const Text('Are you sure you want to delete this medicine?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await context.read<MedicinesProvider>().deleteMedicine(_currentMedicine.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _updateStock() async {
    int newQty = _currentMedicine.quantity;
    final res = await showDialog<int>(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update Stock'),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setDialogState(() => newQty = newQty > 0 ? newQty - 1 : 0),
                  ),
                  Text('$newQty', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setDialogState(() => newQty++),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(c, newQty), child: const Text('Save')),
              ],
            );
          }
        );
      },
    );

    if (res != null && mounted) {
      try {
        await context.read<MedicinesProvider>().updateStock(_currentMedicine.id, res);
        _updateMedicineFromProvider();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to provider changes to reflect edits
    final provider = context.watch<MedicinesProvider>();
    final mIndex = provider.medicines.indexWhere((m) => m.id == _currentMedicine.id);
    if (mIndex != -1) {
      _currentMedicine = provider.medicines[mIndex];
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Color(int.parse(
        _currentMedicine.color.replaceAll('#', '0xFF')));
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Compartment ${_currentMedicine.compartmentNumber}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!_currentMedicine.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Inactive',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currentMedicine.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _currentMedicine.dosage,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditMedicineScreen(medicine: _currentMedicine),
                    ),
                  ).then((_) => _updateMedicineFromProvider());
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (val) {
                  if (val == 'toggle') _toggleActive();
                  if (val == 'delete') _deleteMedicine();
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(_currentMedicine.isActive ? 'Mark Inactive' : 'Mark Active'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ],
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(
                    context: context,
                    title: 'Schedule & Reminders',
                    icon: Icons.calendar_month,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_currentMedicine.reminderTimes.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _currentMedicine.reminderTimes.map((t) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: color.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time, size: 16, color: color),
                                  const SizedBox(width: 4),
                                  Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                                ],
                              ),
                            )).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          children: [
                            const Icon(Icons.play_circle_outline, size: 16, color: AppColors.textSecondaryLight),
                            const SizedBox(width: 8),
                            Text('Starts: ${DateFormat.yMMMd().format(_currentMedicine.startDate)}'),
                          ],
                        ),
                        if (_currentMedicine.endDate != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.stop_circle_outlined, size: 16, color: AppColors.textSecondaryLight),
                              const SizedBox(width: 8),
                              Text('Ends: ${DateFormat.yMMMd().format(_currentMedicine.endDate!)}'),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildInfoCard(
                    context: context,
                    title: 'Inventory',
                    icon: Icons.inventory_2,
                    action: TextButton(
                      onPressed: _updateStock,
                      child: Text('Update', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_currentMedicine.quantity} remaining',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              if (_currentMedicine.isLowStock)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4.0),
                                  child: Text('Low stock warning!', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _currentMedicine.isLowStock ? AppColors.warning.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _currentMedicine.isLowStock ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                            color: _currentMedicine.isLowStock ? AppColors.warning : AppColors.success,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildInfoCard(
                    context: context,
                    title: 'Instructions',
                    icon: Icons.info_outline,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.restaurant, size: 20, color: AppColors.textSecondaryLight),
                            const SizedBox(width: 8),
                            Text(_currentMedicine.foodInstruction, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        if ((_currentMedicine.notes ?? '').isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 12),
                          const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(_currentMedicine.notes ?? ''),
                        ],
                      ],
                    ),
                  ),

                  if (_currentMedicine.expiryDate != null) ...[
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      context: context,
                      title: 'Expiry',
                      icon: Icons.event_busy,
                      child: Row(
                        children: [
                          Icon(
                            _currentMedicine.isExpired ? Icons.cancel : (_currentMedicine.isExpiringSoon ? Icons.warning : Icons.check_circle),
                            color: _currentMedicine.isExpired ? AppColors.error : (_currentMedicine.isExpiringSoon ? AppColors.warning : AppColors.success),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat.yMMMd().format(_currentMedicine.expiryDate!),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _currentMedicine.isExpired ? AppColors.error : (_currentMedicine.isExpiringSoon ? AppColors.warning : (isDark ? Colors.white : Colors.black87)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Text('Recent History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  if (_isLoadingHistory)
                    const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
                  else if (_doseHistory.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight.withOpacity(isDark ? 0.2 : 1)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.history_toggle_off, size: 48, color: AppColors.textSecondaryLight),
                          SizedBox(height: 16),
                          Text('No dose history available.', style: TextStyle(color: AppColors.textSecondaryLight)),
                        ],
                      ),
                    )
                  else
                    ..._doseHistory.map((d) => _buildDoseRecordTile(d, isDark)),
                    
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
        border: Border.all(color: AppColors.borderLight.withOpacity(isDark ? 0.2 : 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.textSecondaryLight),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const Spacer(),
                if (action != null) action,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildDoseRecordTile(DoseRecordModel record, bool isDark) {
    Color statusColor;
    IconData statusIcon;
    switch (record.status) {
      case 'taken':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'missed':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        break;
      case 'skipped':
        statusColor = AppColors.textSecondaryLight;
        statusIcon = Icons.skip_next;
        break;
      default:
        statusColor = AppColors.primary;
        statusIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight.withOpacity(isDark ? 0.2 : 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM d, yyyy - h:mm a').format(record.scheduledTime),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                if (record.takenTime != null)
                  Text(
                    'Taken at ${DateFormat('h:mm a').format(record.takenTime!)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              record.status.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
