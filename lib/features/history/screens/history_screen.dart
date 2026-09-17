import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/constants/app_colors.dart';
import 'package:medisync/core/services/api_service.dart';
import 'package:medisync/models/dose_record_model.dart';

class HistoryScreen extends StatefulWidget {
  final String? patientId; // optional: show history for a specific patient
  const HistoryScreen({super.key, this.patientId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  
  List<DoseRecordModel> _records = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  String _selectedStatus = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _hasMore = true;

  final List<String> _statusFilters = ['all', 'taken', 'missed', 'snoozed'];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _fetchHistory({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _hasMore = true;
      });
    } else if (_page == 1) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final fromStr = _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : null;
      final toStr = _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : null;
      
      final data = await DoseApi.getHistory(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        from: fromStr,
        to: toStr,
        page: _page,
      );

      final List<DoseRecordModel> newRecords = data.map((e) => DoseRecordModel.fromJson(e)).toList();

      setState(() {
        if (_page == 1) {
          _records = newRecords;
        } else {
          _records.addAll(newRecords);
        }
        _hasMore = newRecords.length == 25; // Assuming limit is 25
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load history: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _isLoadingMore = true;
      _page++;
    });
    await _fetchHistory();
  }

  Future<void> _selectDateRange() async {
    final initialDateRange = DateTimeRange(
      start: _fromDate ?? DateTime.now().subtract(const Duration(days: 7)),
      end: _toDate ?? DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _fetchHistory(refresh: true);
    }
  }

  void _clearDateFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _fetchHistory(refresh: true);
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(dateToCheck);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'taken':
        return AppColors.success;
      case 'missed':
        return AppColors.error;
      case 'snoozed':
        return AppColors.warning;
      case 'pending':
      default:
        return AppColors.textSecondaryLight;
    }
  }

  Map<String, List<DoseRecordModel>> _groupRecordsByDate() {
    final Map<String, List<DoseRecordModel>> grouped = {};
    for (var record in _records) {
      final dateStr = DateFormat('yyyy-MM-dd').format(record.scheduledTime);
      if (!grouped.containsKey(dateStr)) {
        grouped[dateStr] = [];
      }
      grouped[dateStr]!.add(record);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Filter by date range',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(isDark),
          Expanded(
            child: _isLoading 
                ? _buildShimmer(isDark)
                : RefreshIndicator(
                    onRefresh: () => _fetchHistory(refresh: true),
                    color: AppColors.primary,
                    child: _records.isEmpty
                        ? _buildEmptyState(isDark)
                        : _buildHistoryList(isDark),
                  ),
          ),
          if (_isLoadingMore)
            Container(
              padding: const EdgeInsets.all(16.0),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: _statusFilters.map((status) {
                final isSelected = _selectedStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected 
                            ? Colors.white 
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        _selectedStatus = status;
                      });
                      _fetchHistory(refresh: true);
                    },
                    backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200],
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_fromDate != null && _toDate != null)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.event_available, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormat('MMM d').format(_fromDate!)} - ${DateFormat('MMM d').format(_toDate!)}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _clearDateFilter,
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(bool isDark) {
    final groupedData = _groupRecordsByDate();
    final dates = groupedData.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Sort descending

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final dateStr = dates[index];
        final recordsForDate = groupedData[dateStr]!;
        final headerDate = DateTime.parse(dateStr);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 12.0, left: 4.0),
              child: Text(
                _formatDateHeader(headerDate),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            ...recordsForDate.map((record) => _buildDoseCard(record, isDark)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildDoseCard(DoseRecordModel record, bool isDark) {
    final statusColor = _getStatusColor(record.status);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? [] : AppColors.cardShadow,
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : AppColors.borderLight,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                record.isTaken ? Icons.check_circle_outline :
                record.isMissed ? Icons.cancel_outlined :
                record.isSnoozed ? Icons.snooze : Icons.access_time,
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.medicineName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.dosage,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: AppColors.textSecondaryLight),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(record.scheduledTime),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      if (record.isTaken && record.takenTime != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.done_all, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          'Taken ${DateFormat('h:mm a').format(record.takenTime!)}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ]
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                record.status[0].toUpperCase() + record.status.substring(1),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No history found',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Change filters or check back later',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer(bool isDark) {
    final baseColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey[300]!;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF333333) : AppColors.borderLight,
            ),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 1500),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 1500),
                      width: 150,
                      height: 16,
                      color: baseColor,
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 1500),
                      width: 80,
                      height: 12,
                      color: baseColor,
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 1500),
                      width: 120,
                      height: 12,
                      color: baseColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
