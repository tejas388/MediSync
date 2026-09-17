// lib/features/medicines/screens/medicines_screen.dart
// MediSync - Medicines list with search, filter, FAB

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../medicines_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/extensions.dart';
import '../../../models/medicine_model.dart';
import 'add_edit_medicine_screen.dart';
import 'medicine_detail_screen.dart';

class MedicinesScreen extends StatefulWidget {
  final String? patientId; // optional: show medicines for a specific patient
  const MedicinesScreen({super.key, this.patientId});
  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        context.read<MedicinesProvider>().loadMedicines(patientId: widget.patientId));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MedicinesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search medicines…',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: prov.setSearch,
              )
            : const Text('Medicines'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search_rounded),
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) {
                _searchCtrl.clear();
                prov.setSearch(null);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: 'Active (${prov.activeMedicines.length})'),
            Tab(text: 'All (${prov.allMedicines.length})'),
          ],
        ),
      ),
      body: prov.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => prov.loadMedicines(patientId: widget.patientId),
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _MedicineList(medicines: prov.activeMedicines),
                  _MedicineList(medicines: prov.medicines),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_medicine',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddEditMedicineScreen(patientId: widget.patientId)),
        ).then((_) => prov.loadMedicines(patientId: widget.patientId)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Medicine'),
      ),
    );
  }
}

class _MedicineList extends StatelessWidget {
  final List<MedicineModel> medicines;
  const _MedicineList({required this.medicines});

  @override
  Widget build(BuildContext context) {
    if (medicines.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.medication_outlined, size: 72, color: AppColors.textTertiaryLight),
          const SizedBox(height: 16),
          Text('No medicines yet', style: context.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Tap + to add your first medicine',
              style: context.textTheme.bodyMedium),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: medicines.length,
      itemBuilder: (_, i) => _MedicineCard(medicine: medicines[i]),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final MedicineModel medicine;
  const _MedicineCard({required this.medicine});

  @override
  Widget build(BuildContext context) {
    final color = medicine.color.hexColor;
    final prov  = context.read<MedicinesProvider>();

    return Dismissible(
      key: ValueKey(medicine.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Medicine?'),
            content: Text('Remove ${medicine.name} from your list? This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => prov.deleteMedicine(medicine.id),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MedicineDetailScreen(medicine: medicine)),
        ).then((_) => prov.loadMedicines()),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: Row(children: [
            // Color dot + compartment
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.medication_rounded, color: color, size: 22),
                Text('C${medicine.compartmentNumber}',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 9,
                        fontWeight: FontWeight.w700, color: color)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(medicine.name,
                    style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15))),
                if (medicine.isLowStock)
                  const _Badge('Low Stock', AppColors.error),
                if (medicine.isExpiringSoon)
                  const _Badge('Expiring', AppColors.warning),
              ]),
              const SizedBox(height: 4),
              Text('${medicine.dosage}  •  ${medicine.foodInstruction}',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
                      color: AppColors.textSecondaryLight)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.inventory_2_outlined, size: 13, color: AppColors.textSecondaryLight),
                const SizedBox(width: 4),
                Text('${medicine.quantity} tablets',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
                        color: AppColors.textSecondaryLight)),
                const SizedBox(width: 12),
                const Icon(Icons.alarm_rounded, size: 13, color: AppColors.textSecondaryLight),
                const SizedBox(width: 4),
                Text(medicine.reminderTimes.join(', '),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
                        color: AppColors.textSecondaryLight)),
              ]),
            ])),
            // Active toggle
            Switch(
              value: medicine.isActive,
              onChanged: (_) => prov.toggleActive(medicine.id),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text; final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(fontFamily: 'Inter', fontSize: 9,
        fontWeight: FontWeight.w700, color: color)),
  );
}
