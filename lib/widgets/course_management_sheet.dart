import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/intake_log.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'toast_helper.dart';

/// Шторка управления курсом приёма медикаментов (Микро-спринт 11).
/// Позволяет:
/// 1. Продлить курс (+7, +14, +30 дней).
/// 2. Приостановить курс (is_active = false) / возобновить.
/// 3. Завершить досрочно.
/// 4. Сбросить перенос (+15 мин) к исходному слоту.
/// 5. Удалить курс с подтверждением.
class CourseManagementSheet extends StatelessWidget {
  final int courseId;
  final String courseTitle;
  final IntakeLog? currentLog;
  final bool isSnoozed;

  const CourseManagementSheet({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.currentLog,
    this.isSnoozed = false,
  });

  static Future<void> show(
    BuildContext context, {
    required int courseId,
    required String courseTitle,
    IntakeLog? currentLog,
    bool isSnoozed = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CourseManagementSheet(
        courseId: courseId,
        courseTitle: courseTitle,
        currentLog: currentLog,
        isSnoozed: isSnoozed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantics = theme.extension<SemanticColors>() ?? SemanticColors.light;
    final state = context.read<AppState>();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_repeat_rounded, color: cs.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Управление курсом',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      courseTitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 12),

          // 1. Reset Snooze (if current intake was snoozed)
          if (currentLog != null)
            _buildActionTile(
              context,
              icon: Icons.restore_rounded,
              iconColor: cs.primary,
              title: 'Сбросить перенос (+15 мин)',
              subtitle: 'Вернуть приём к исходному запланированному времени слота',
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  await state.resetSnoozeIntake(currentLog!.id);
                  if (context.mounted) {
                    ToastHelper.show(
                      context,
                      message: 'Перенос отменён. Возвращено исходное время приёма.',
                      icon: '⏱️',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ToastHelper.showError(context, 'Не удалось сбросить перенос: проверьте сеть');
                  }
                }
              },
            ),

          // 2. Extend Course
          _buildActionTile(
            context,
            icon: Icons.more_time_rounded,
            iconColor: semantics.success,
            title: 'Продлить курс приёма',
            subtitle: 'Добавить ещё 7, 14 или 30 дней напоминаний',
            onTap: () => _showExtendDialog(context, state),
          ),

          // 3. Pause Course
          _buildActionTile(
            context,
            icon: Icons.pause_circle_outline_rounded,
            iconColor: semantics.warning,
            title: 'Приостановить курс',
            subtitle: 'Временно отключить будущие напоминания',
            onTap: () async {
              Navigator.of(context).pop();
              try {
                await state.updateIntakeCourse(courseId, {'is_active': false});
                if (context.mounted) {
                  ToastHelper.show(
                    context,
                    message: 'Курс «$courseTitle» временно приостановлен.',
                    icon: '⏸️',
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ToastHelper.showError(context, 'Ошибка приостановки курса');
                }
              }
            },
          ),

          // 4. Finish Early
          _buildActionTile(
            context,
            icon: Icons.check_circle_outline_rounded,
            iconColor: cs.secondary,
            title: 'Завершить курс досрочно',
            subtitle: 'Отменить будущие запланированные приёмы',
            onTap: () => _confirmFinishEarly(context, state),
          ),

          // 5. Delete Course
          _buildActionTile(
            context,
            icon: Icons.delete_outline_rounded,
            iconColor: semantics.danger,
            title: 'Удалить курс лечения',
            subtitle: 'Удалить курс и все связанные с ним невыполненные напоминания',
            isDestructive: true,
            onTap: () => _confirmDeleteCourse(context, state),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantics = theme.extension<SemanticColors>() ?? SemanticColors.light;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive ? semantics.dangerBg : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? semantics.dangerText : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showExtendDialog(BuildContext context, AppState state) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    int selectedDays = 7;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.outlineVariant),
          ),
          title: Text(
            'Продление курса',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Выберите, на сколько дней продлить курс «$courseTitle»:',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('+7 дней')),
                  ButtonSegment(value: 14, label: Text('+14 дней')),
                  ButtonSegment(value: 30, label: Text('+30 дней')),
                ],
                selected: {selectedDays},
                onSelectionChanged: (newVal) {
                  setDialogState(() => selectedDays = newVal.first);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Отмена', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                try {
                  await state.extendIntakeCourse(courseId, selectedDays);
                  if (context.mounted) {
                    ToastHelper.show(
                      context,
                      message: 'Курс продлён на $selectedDays дн. Расписание обновлено.',
                      icon: '📅',
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ToastHelper.showError(context, 'Ошибка при продлении курса');
                  }
                }
              },
              child: const Text('Продлить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmFinishEarly(BuildContext context, AppState state) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.outlineVariant),
        ),
        title: Text(
          'Завершить курс досрочно?',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          'Курс «$courseTitle» будет закрыт сегодняшней датой, а все последующие запланированные напоминания будут удалены.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Отмена', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
      try {
        final nowStr = DateTime.now().toIso8601String().substring(0, 10);
        await state.updateIntakeCourse(courseId, {'is_active': false, 'end_date': nowStr});
        if (context.mounted) {
          ToastHelper.show(
            context,
            message: 'Курс успешно завершён досрочно.',
            icon: '✓',
          );
        }
      } catch (_) {
        if (context.mounted) {
          ToastHelper.showError(context, 'Ошибка завершения курса');
        }
      }
    }
  }

  Future<void> _confirmDeleteCourse(BuildContext context, AppState state) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantics = theme.extension<SemanticColors>() ?? SemanticColors.light;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: semantics.dangerBorder),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: semantics.danger),
            const SizedBox(width: 8),
            Text(
              'Удалить курс?',
              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'Вы действительно хотите удалить курс «$courseTitle»? Все связанные напоминания и расписание будут безвозвратно удалены.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Отмена', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: semantics.danger,
              foregroundColor: cs.onPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
      try {
        await state.deleteIntakeCourse(courseId);
        if (context.mounted) {
          ToastHelper.show(
            context,
            message: 'Курс «$courseTitle» успешно удалён.',
            icon: '🗑️',
          );
        }
      } catch (_) {
        if (context.mounted) {
          ToastHelper.showError(context, 'Ошибка при удалении курса');
        }
      }
    }
  }
}
