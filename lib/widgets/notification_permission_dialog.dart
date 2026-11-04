import 'package:flutter/material.dart';
import '../services/local_notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Диалог-объяснение необходимости разрешений на уведомления (Android 13+).
/// Показывается пользователю перед системным системным запросом разрешений,
/// объясняя клиническую важность своевременного напоминания и будильников.
class NotificationPermissionDialog extends StatelessWidget {
  final StorageService storageService;
  final LocalNotificationService notificationService;

  const NotificationPermissionDialog({
    super.key,
    required this.storageService,
    required this.notificationService,
  });

  static Future<bool?> showIfNeeded(
    BuildContext context, {
    required StorageService storageService,
    LocalNotificationService? notificationService,
  }) async {
    final alreadyShown = await storageService.hasNotificationRationaleShown();
    if (alreadyShown) return null;

    if (!context.mounted) return null;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NotificationPermissionDialog(
        storageService: storageService,
        notificationService: notificationService ?? LocalNotificationService.instance,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantics = theme.extension<SemanticColors>() ?? SemanticColors.light;

    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: cs.onPrimaryContainer,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Напоминания о лекарствах',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Чтобы вы и члены вашей семьи не пропускали приём медикаментов, приложению требуется разрешение на отправку уведомлений и точных будильников.',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureRow(
              icon: Icons.alarm_rounded,
              iconColor: cs.primary,
              title: 'Канал «Будильник»',
              desc: 'Точные громкие напоминания строго по расписанию даже в беззвучном режиме.',
              cs: cs,
            ),
            const SizedBox(height: 12),
            _buildFeatureRow(
              icon: Icons.touch_app_rounded,
              iconColor: semantics.success,
              title: 'Действия в шторке',
              desc: 'Кнопки «Принял» и «Отложить на 15 мин» прямо в уведомлении.',
              cs: cs,
            ),
            const SizedBox(height: 12),
            _buildFeatureRow(
              icon: Icons.restart_alt_rounded,
              iconColor: semantics.warning,
              title: 'После перезагрузки',
              desc: 'Автоматическое восстановление точных будильников при включении телефона.',
              cs: cs,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await storageService.setNotificationRationaleShown(true);
            if (context.mounted) {
              Navigator.of(context).pop(false);
            }
          },
          child: Text(
            'Позже',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: () async {
            await storageService.setNotificationRationaleShown(true);
            final granted = await notificationService.requestPermissions();
            if (context.mounted) {
              Navigator.of(context).pop(granted);
            }
          },
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Разрешить'),
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    required ColorScheme cs,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
