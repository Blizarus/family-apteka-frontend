import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_item.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'toast_helper.dart';

class NotificationCenterSheet extends StatelessWidget {
  const NotificationCenterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationCenterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);

    final state = context.watch<AppState>();
    final notifications = state.notifications;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: cs.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Центр уведомлений',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                          if (notifications.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${notifications.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Сигналы о сроках годности и запасах',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: textMuted),
                  tooltip: 'Закрыть',
                ),
              ],
            ),
          ),

          Divider(height: 1, color: cs.outlineVariant),

          // List or Empty State
          Expanded(
            child: notifications.isEmpty
                ? _buildEmptyState(context, cs, textMuted)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return _buildNotificationCard(context, state, item, cs, semantic, textMuted);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme cs, Color textMuted) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: cs.outlineVariant, width: 1.5),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 38,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'У вас нет новых уведомлений. Всё под контролем!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Все препараты в норме, просрочек нет и курсы лечения актуальны.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    AppState state,
    NotificationItem item,
    ColorScheme cs,
    SemanticColors semantic,
    Color textMuted,
  ) {
    final styleInfo = _getTypeStyle(item.type, cs, semantic);
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline_rounded, color: cs.onError, size: 22),
            const SizedBox(width: 6),
            Text(
              'Удалить',
              style: TextStyle(
                color: cs.onError,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        state.deleteNotification(item.id);
        ToastHelper.show(context, message: 'Уведомление удалено');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: styleInfo.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: styleInfo.borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
                border: Border.all(color: styleInfo.borderColor),
              ),
              child: Icon(
                styleInfo.icon,
                color: styleInfo.iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: styleInfo.titleColor,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(item.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: Icon(Icons.close_rounded, color: textMuted),
              tooltip: 'Удалить',
              onPressed: () {
                state.deleteNotification(item.id);
                ToastHelper.show(context, message: 'Уведомление удалено');
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes.clamp(1, 60);
      return '$mins мин назад';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else {
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      return '$d.$mo';
    }
  }

  _NotificationStyle _getTypeStyle(String type, ColorScheme cs, SemanticColors semantic) {
    switch (type) {
      case 'expiry_critical':
      case 'opened_expired':
        return _NotificationStyle(
          icon: Icons.warning_amber_rounded,
          iconColor: semantic.danger,
          titleColor: semantic.dangerText,
          backgroundColor: semantic.dangerBg,
          borderColor: semantic.dangerBorder,
        );
      case 'expiry_warning_7d':
      case 'expiry_warning_30d':
        return _NotificationStyle(
          icon: Icons.access_time_filled_rounded,
          iconColor: semantic.warning,
          titleColor: semantic.warningText,
          backgroundColor: semantic.warningBg,
          borderColor: semantic.warningBorder,
        );
      case 'low_stock':
        return _NotificationStyle(
          icon: Icons.inventory_2_outlined,
          iconColor: semantic.info,
          titleColor: semantic.infoText,
          backgroundColor: semantic.infoBg,
          borderColor: semantic.infoBorder,
        );
      case 'intake_reminder':
      default:
        return _NotificationStyle(
          icon: Icons.medication_rounded,
          iconColor: cs.primary,
          titleColor: cs.primary,
          backgroundColor: cs.primaryContainer,
          borderColor: cs.outlineVariant,
        );
    }
  }
}

class _NotificationStyle {
  final IconData icon;
  final Color iconColor;
  final Color titleColor;
  final Color backgroundColor;
  final Color borderColor;

  const _NotificationStyle({
    required this.icon,
    required this.iconColor,
    required this.titleColor,
    required this.backgroundColor,
    required this.borderColor,
  });
}
