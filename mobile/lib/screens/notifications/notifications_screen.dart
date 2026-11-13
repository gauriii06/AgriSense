import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../services/misc_services.dart';
import '../../widgets/section_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = NotificationService();
  List<dynamic> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Ensure fresh alerts exist (evaluates current conditions, dedups
      // against already-active alerts), then list full notification history.
      try {
        await _notificationService.generateAlerts();
      } catch (_) {
        // Non-fatal — still show whatever history exists.
      }
      final list = await _notificationService.list();
      setState(() => _notifications = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead(int notificationId, int alertId) async {
    // Optimistic update so the tap feels instant.
    setState(() {
      final n = _notifications.firstWhere((n) => n['notification_id'] == notificationId);
      n['is_read'] = true;
      n['status'] = 'read';
    });
    try {
      await _notificationService.markRead(notificationId);
    } catch (_) {
      _load(); // fall back to a full reload if the optimistic update was wrong
    }
  }

  Future<void> _dismiss(int alertId) async {
    final removed = _notifications.firstWhere((n) => n['alert_id'] == alertId, orElse: () => null);
    setState(() => _notifications.removeWhere((n) => n['alert_id'] == alertId));
    try {
      await _notificationService.dismissAlert(alertId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Alert dismissed'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // Dismissal history is preserved server-side, so a full
                // reload will still show it — just re-fetch instead of
                // trying to reverse a "dismiss" on the server.
                _load();
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Restore the item locally if the server call failed.
      if (removed != null && mounted) {
        setState(() => _notifications.insert(0, removed));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not dismiss: $e')));
      }
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'weather':
        return Icons.wb_cloudy_outlined;
      case 'pest':
        return Icons.bug_report_outlined;
      case 'disease':
        return Icons.local_florist_outlined;
      case 'market':
        return Icons.storefront_outlined;
      case 'irrigation':
        return Icons.water_drop_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _notifications.where((n) => n['status'] == 'active').toList();
    final history = _notifications.where((n) => n['status'] != 'active').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorRetryView(message: _error!, onRetry: _load)
              : _notifications.isEmpty
                  ? const Center(child: Text('No notifications yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (active.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text('Active', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                            ),
                            ...active.map(_buildCard),
                            const SizedBox(height: 16),
                          ],
                          if (history.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text('History', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                            ),
                            ...history.map(_buildCard),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildCard(dynamic n) {
    final isRead = n['is_read'] == 1 || n['is_read'] == true;
    final status = n['status'] ?? 'active';
    final alertId = n['alert_id'];

    final card = SectionCard(
      title: n['title'] ?? '',
      icon: _iconFor(n['type'] ?? ''),
      iconColor: AppColors.riskColor(n['severity'] ?? 'low'),
      onTap: (status == 'active' && !isRead) ? () => _markRead(n['notification_id'], alertId) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n['message'] ?? ''),
          if (n['recommended_action'] != null) ...[
            const SizedBox(height: 6),
            Text(n['recommended_action'], style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                DateFormat('MMM d, h:mm a').format(HttpDate.parse(n['created_at']).toLocal()),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const Spacer(),
              if (status == 'active' && !isRead) const StatusPill(label: 'NEW', color: AppColors.waterBlue),
              if (status == 'dismissed') const StatusPill(label: 'DISMISSED', color: AppColors.textMuted),
              if (status == 'resolved') const StatusPill(label: 'RESOLVED', color: AppColors.primaryGreen),
              if (status == 'read') const StatusPill(label: 'READ', color: AppColors.textMuted),
            ],
          ),
        ],
      ),
    );

    // Only active alerts are dismissable — swipe left to dismiss.
    if (status != 'active' || alertId == null) return card;

    return Dismissible(
      key: ValueKey('alert-$alertId'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(color: AppColors.alertRed, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.close, color: Colors.white),
      ),
      onDismissed: (_) => _dismiss(alertId),
      child: card,
    );
  }
}
