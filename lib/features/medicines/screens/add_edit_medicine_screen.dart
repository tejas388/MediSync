import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medisync/features/medicines/medicines_provider.dart';
import 'package:medisync/models/medicine_model.dart';
import 'package:medisync/core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/services/api_service.dart';

class AddEditMedicineScreen extends StatefulWidget {
  final MedicineModel? medicine;
  final String? patientId;

  const AddEditMedicineScreen({super.key, this.medicine, this.patientId});

  @override
  State<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends State<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _notesController;
  
  int _compartmentNumber = 1;
  late String _selectedColor;
  int _quantity = 30;
  String _foodInstruction = 'No restriction';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  DateTime? _expiryDate;
  List<String> _reminderTimes = [];
  
  List<dynamic> _patients = [];
  final List<String> _selectedPatientIds = [];
  
  bool _isLoading = false;

  final List<String> _availableColors = [
    '#F44336', '#E91E63', '#9C27B0', '#3F51B5', '#2196F3', '#00BCD4', '#009688', '#4CAF50', '#8BC34A', '#FFEB3B', '#FF9800', '#FF5722'
  ];

  final List<String> _foodInstructions = [
    'No restriction',
    'Before meals',
    'After meals',
    'With meals'
  ];

  @override
  void initState() {
    super.initState();
    final med = widget.medicine;
    _nameController = TextEditingController(text: med?.name ?? '');
    _dosageController = TextEditingController(text: med?.dosage ?? '');
    _notesController = TextEditingController(text: med?.notes ?? '');
    
    if (med != null) {
      _compartmentNumber = med.compartmentNumber;
      _selectedColor = med.color;
      _quantity = med.quantity;
      _foodInstruction = med.foodInstruction;
      _startDate = med.startDate;
      _endDate = med.endDate;
      _expiryDate = med.expiryDate;
      _reminderTimes = List.from(med.reminderTimes);
    } else {
      _selectedColor = _availableColors[0];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final prov = context.read<MedicinesProvider>();
        final occupied = prov.sharedCompartments.keys.toSet();
        for (int i = 1; i <= 7; i++) {
          if (!occupied.contains(i)) {
            setState(() => _compartmentNumber = i);
            break;
          }
        }
        
        CaregiverApi.getPatients().then((pts) {
          if (mounted) {
            setState(() {
              _patients = pts;
              // If we know the current patient, pre-select them
              if (prov.currentPatientId != null) {
                _selectedPatientIds.add(prov.currentPatientId!);
              } else if (pts.isNotEmpty) {
                _selectedPatientIds.add(pts.first['id'] as String);
              }
            });
          }
        }).catchError((_) {}); // Ignore if user is not a caregiver
      });
    }
    
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (!mounted) return;
    final prov = context.read<MedicinesProvider>();
    final name = _nameController.text.trim().toLowerCase();
    if (name.isEmpty) return;
    
    for (final entry in prov.sharedCompartments.entries) {
      if (entry.value.toLowerCase().trim() == name) {
        if (_compartmentNumber != entry.key) {
           setState(() => _compartmentNumber = entry.key);
        }
        break;
      }
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      final String formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      if (!_reminderTimes.contains(formattedTime)) {
        setState(() {
          _reminderTimes.add(formattedTime);
          _reminderTimes.sort();
        });
      }
    }
  }

  Future<void> _selectDate({required bool isStart, bool isExpiry = false}) async {
    final DateTime initialDate = isStart 
        ? _startDate 
        : (isExpiry ? (_expiryDate ?? DateTime.now()) : (_endDate ?? DateTime.now()));
        
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else if (isExpiry) {
          _expiryDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final data = {
        'name': _nameController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'compartmentNumber': _compartmentNumber,
        'color': _selectedColor,
        'quantity': _quantity,
        'foodInstruction': _foodInstruction,
        'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
        if (_endDate != null)
          'endDate': DateFormat('yyyy-MM-dd').format(_endDate!),
        if (_expiryDate != null)
          'expiryDate': DateFormat('yyyy-MM-dd').format(_expiryDate!),
        'reminderTimes': _reminderTimes,
        'notes': _notesController.text.trim(),
      };

      final provider = context.read<MedicinesProvider>();
      
      if (widget.medicine == null) {
        if (_patients.isNotEmpty && _selectedPatientIds.isEmpty) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select at least one patient.'), backgroundColor: AppColors.error),
          );
          return;
        }

        if (_patients.isNotEmpty) {
           for (final pid in _selectedPatientIds) {
             await CaregiverApi.addMedicineForPatient(pid, data);
           }
           if (provider.currentPatientId != null && _selectedPatientIds.contains(provider.currentPatientId)) {
             await provider.loadMedicines(patientId: provider.currentPatientId);
           }
        } else {
           await provider.addMedicine(data);
        }
      } else {
        await provider.updateMedicine(widget.medicine!.id, data);
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving medicine: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.medicine != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Medicine' : 'Add Medicine'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _save,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Basic Details'),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Medicine Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        prefixIcon: Icon(Icons.medical_information),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dosageController,
                      decoration: const InputDecoration(
                        labelText: 'Dosage (e.g., 500mg, 1 pill)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        prefixIcon: Icon(Icons.vaccines),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    
                    if (!isEditing && _patients.isNotEmpty) ...[
                      _buildSectionHeader('Assign to Patient(s)'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _patients.map((p) {
                          final pId = p['id'] as String;
                          final isSelected = _selectedPatientIds.contains(pId);
                          return FilterChip(
                            label: Text(p['name'] as String),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedPatientIds.add(pId);
                                } else {
                                  _selectedPatientIds.remove(pId);
                                }
                              });
                            },
                            selectedColor: AppColors.primary.withOpacity(0.2),
                            checkmarkColor: AppColors.primary,
                          );
                        }).toList(),
                      ),
                      if (_selectedPatientIds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Please select at least one patient.', style: TextStyle(color: AppColors.error, fontSize: 12)),
                        ),
                    ],

                    _buildSectionHeader('Dispenser Compartment'),
                    Consumer<MedicinesProvider>(
                      builder: (context, prov, child) {
                        final occupied = prov.sharedCompartments;
                        final currentName = _nameController.text.trim().toLowerCase();
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (occupied.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Currently occupied globally:\n${occupied.entries.map((e) => '• Comp ${e.key}: ${e.value}').join('\n')}',
                                  style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
                                ),
                              ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(7, (index) {
                                  final compNum = index + 1;
                                  final isSelected = _compartmentNumber == compNum;
                                  
                                  // A compartment is considered conflicted (occupied & locked) if 
                                  // it has a DIFFERENT medicine in it.
                                  final hasOtherMedicine = occupied.containsKey(compNum) && 
                                                           occupied[compNum]?.toLowerCase().trim() != currentName;
                                                           
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text('Comp $compNum'),
                                      selected: isSelected,
                                      onSelected: hasOtherMedicine ? null : (selected) {
                                        if (selected) setState(() => _compartmentNumber = compNum);
                                      },
                                      selectedColor: AppColors.primary.withOpacity(0.2),
                                      disabledColor: Colors.grey.withOpacity(0.1),
                                      labelStyle: TextStyle(
                                        color: hasOtherMedicine ? Colors.grey : (isSelected ? AppColors.primary : (isDark ? Colors.white : Colors.black87)),
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        decoration: hasOtherMedicine ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    
                    _buildSectionHeader('Color Tag'),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _availableColors.map((colorHex) {
                          final color = Color(int.parse(colorHex.replaceAll('#', '0xFF')));
                          final isSelected = _selectedColor == colorHex;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = colorHex),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: isDark ? Colors.white : Colors.black, width: 3) : null,
                                boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)] : null,
                              ),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    _buildSectionHeader('Inventory & Instructions'),
                    Row(
                      children: [
                        const Text('Quantity:', style: TextStyle(fontSize: 16)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => setState(() => _quantity = _quantity > 0 ? _quantity - 1 : 0),
                          color: AppColors.primary,
                        ),
                        Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setState(() => _quantity++),
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _foodInstruction,
                      decoration: const InputDecoration(
                        labelText: 'Food Instruction',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        prefixIcon: Icon(Icons.restaurant),
                      ),
                      items: _foodInstructions.map((inst) => DropdownMenuItem(value: inst, child: Text(inst))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _foodInstruction = v);
                      },
                    ),

                    _buildSectionHeader('Schedule'),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                      title: const Text('Start Date'),
                      subtitle: Text(DateFormat.yMMMd().format(_startDate)),
                      trailing: const Icon(Icons.edit, size: 20),
                      onTap: () => _selectDate(isStart: true),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_busy, color: AppColors.primary),
                      title: const Text('End Date (Optional)'),
                      subtitle: Text(_endDate != null ? DateFormat.yMMMd().format(_endDate!) : 'Not set'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_endDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () => setState(() => _endDate = null),
                            ),
                          const Icon(Icons.edit, size: 20),
                        ],
                      ),
                      onTap: () => _selectDate(isStart: false),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                      title: const Text('Expiry Date (Optional)'),
                      subtitle: Text(_expiryDate != null ? DateFormat.yMMMd().format(_expiryDate!) : 'Not set'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_expiryDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () => setState(() => _expiryDate = null),
                            ),
                          const Icon(Icons.edit, size: 20),
                        ],
                      ),
                      onTap: () => _selectDate(isStart: false, isExpiry: true),
                    ),
                    
                    _buildSectionHeader('Reminder Times'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._reminderTimes.map((time) => Chip(
                          label: Text(time, style: const TextStyle(fontWeight: FontWeight.bold)),
                          onDeleted: () => setState(() => _reminderTimes.remove(time)),
                          deleteIcon: const Icon(Icons.cancel, size: 18),
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                        )),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18, color: Colors.white),
                          label: const Text('Add Time', style: TextStyle(color: Colors.white)),
                          backgroundColor: AppColors.primary,
                          onPressed: _pickTime,
                        ),
                      ],
                    ),

                    _buildSectionHeader('Additional Notes'),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Any special instructions, side effects, etc.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _save,
                        child: Text(isEditing ? 'Save Changes' : 'Add Medicine', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
