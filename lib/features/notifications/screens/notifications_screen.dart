import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medisync/core/constants/app_colors.dart';
import 'package:medisync/core/services/api_service.dart';
import 'package:medisync/models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
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

  Future<void> _fetchNotifications({bool refresh = false}) async {
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
      final res = await NotificationApi.getAll(
        page: _page,
        unreadOnly: _showUnreadOnly ? true : null,
      );
      
      final data = res['data'] as List? ?? [];
      final List<NotificationModel> newNotifications = data.map((e) => NotificationModel.fromJson(e)).toList();

      setState(() {
        if (_page == 1) {
          _notifications = newNotifications;
        } else {
          _notifications.addAll(newNotifications);
        }
        _hasMore = newNotifications.length >= 25; // Or check meta pagination info if available
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
            content: Text('Failed to load notifications: $e'),
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
    await _fetchNotifications();
  }

  Future<void> _markAllAsRead() async {
    try {
      await NotificationApi.markAllRead();
      setState(() {
        _notifications = _notifications.map((n) {
          if (!n.isRead) {
            // Recreating model with read status to update UI instantly without re-fetching
            return NotificationModel.fromJson({
              ..._notificationToJson(n),
              'isRead': true,
            });
          }
          return n;
        }).toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark all as read: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;
    
    try {
      await NotificationApi.markRead(notification.id);
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = NotificationModel.fromJson({
            ..._notificationToJson(notification),
            'isRead': true,
          });
        }
      });
    } catch (e) {
      // Silently fail or log
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    try {
      await NotificationApi.delete(notification.id);
      setState(() {
        _notifications.removeWhere((n) => n.id == notification.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notification: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      _fetchNotifications(refresh: true); // Reload if failed
    }
  }

  // Helper function to mock json representation to update read status locally
  Map<String, dynamic> _notificationToJson(NotificationModel n) {
    return {
      'id': n.id,
      'userId': n.userId,
      'title': n.title,
      'body': n.body,
      'type': n.type,
      'isRead': n.isRead,
      'medicineId': n.medicineId,
      'medicineName': n.medicineName,
      'createdAt': n.createdAt.toIso8601String(),
    };
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(dateTime);
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
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

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.doseReminder:   return Icons.medication_rounded;
      case NotificationType.doseMissed:     return Icons.warning_amber_rounded;
      case NotificationType.lowStock:       return Icons.inventory_2_rounded;
      case NotificationType.expiryAlert:    return Icons.event_busy_rounded;
      case NotificationType.caregiverAlert: return Icons.medical_services_rounded;
      case NotificationType.deviceOffline:  return Icons.wifi_off_rounded;
      case NotificationType.emergencySOS:   return Icons.emergency_rounded;
      case NotificationType.scheduleUpdate: return Icons.schedule_rounded;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.doseReminder:   return AppColors.primary;
      case NotificationType.doseMissed:     return AppColors.error;
      case NotificationType.lowStock:       return AppColors.warning;
      case NotificationType.expiryAlert:    return AppColors.error;
      case NotificationType.caregiverAlert: return AppColors.accent;
      case NotificationType.deviceOffline:  return AppColors.textSecondaryLight;
      case NotificationType.emergencySOS:   return AppColors.error;
      case NotificationType.scheduleUpdate: return AppColors.primary;
    }
  }

  Map<String, List<NotificationModel>> _groupNotificationsByDate() {
    final Map<String, List<NotificationModel>> grouped = {};
    for (var notification in _notifications) {
      final dateStr = DateFormat('yyyy-MM-dd').format(notification.createdAt.toLocal());
      if (!grouped.containsKey(dateStr)) {
        grouped[dateStr] = [];
      }
      grouped[dateStr]!.add(notification);
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
          'Notifications',
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
            icon: const Icon(Icons.done_all),
            onPressed: _notifications.isNotEmpty ? _markAllAsRead : null,
            tooltip: 'Mark all as read',
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
                    onRefresh: () => _fetchNotifications(refresh: true),
                    color: AppColors.primary,
                    child: _notifications.isEmpty
                        ? _buildEmptyState(isDark)
                        : _buildNotificationsList(isDark),
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
    int unreadCount = _notifications.where((n) => !n.isRead).length;

    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All', style: TextStyle(fontFamily: 'Inter')),
            selected: !_showUnreadOnly,
            onSelected: (bool selected) {
              setState(() {
                _showUnreadOnly = false;
              });
              _fetchNotifications(refresh: true);
            },
            backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200],
            selectedColor: AppColors.primary,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: !_showUnreadOnly ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: !_showUnreadOnly ? FontWeight.w600 : FontWeight.w400,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: !_showUnreadOnly ? AppColors.primary : Colors.transparent),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unread', style: TextStyle(fontFamily: 'Inter')),
                if (unreadCount > 0 && !_showUnreadOnly) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _showUnreadOnly ? Colors.white24 : AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ]
              ],
            ),
            selected: _showUnreadOnly,
            onSelected: (bool selected) {
              setState(() {
                _showUnreadOnly = true;
              });
              _fetchNotifications(refresh: true);
            },
            backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200],
            selectedColor: AppColors.primary,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: _showUnreadOnly ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: _showUnreadOnly ? FontWeight.w600 : FontWeight.w400,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _showUnreadOnly ? AppColors.primary : Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(bool isDark) {
    final groupedData = _groupNotificationsByDate();
    final dates = groupedData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final dateStr = dates[index];
        final notifsForDate = groupedData[dateStr]!;
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
            ...notifsForDate.map((notif) => _buildNotificationCard(notif, isDark)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification, bool isDark) {
    final typeColor = _getColorForType(notification.type);
    final cardBgColor = notification.isRead
        ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
        : (isDark ? const Color(0xFF25333F) : const Color(0xFFF0F9FF));
        
    final borderColor = notification.isRead
        ? (isDark ? const Color(0xFF333333) : AppColors.borderLight)
        : AppColors.primary.withOpacity(0.3);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (direction) => _deleteNotification(notification),
        child: GestureDetector(
          onTap: () => _markAsRead(notification),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? [] : AppColors.cardShadow,
              border: Border.all(color: borderColor, width: 1),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!notification.isRead)
                    Container(
                      width: 4,
                      color: AppColors.primary,
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getIconForType(notification.type),
                              color: typeColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification.title,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 16,
                                          fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w700,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatRelativeTime(notification.createdAt.toLocal()),
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  notification.body,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
            Icons.notifications_off_outlined,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You're all caught up!",
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 1500),
                          width: 120,
                          height: 16,
                          color: baseColor,
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 1500),
                          width: 60,
                          height: 12,
                          color: baseColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 1500),
                      width: double.infinity,
                      height: 12,
                      color: baseColor,
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 1500),
                      width: 200,
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
