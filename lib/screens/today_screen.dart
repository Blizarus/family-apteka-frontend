import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/intake_log.dart';
import '../models/profile.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/expandable_calendar.dart';
import '../widgets/intake_course_wizard.dart';
import '../widgets/skip_reason_dialog.dart';
import '../widgets/toast_helper.dart';
import '../widgets/notification_center_sheet.dart';
import '../widgets/out_of_stock_dialog.dart';
import '../services/api_service.dart';
import '../services/api_error_handler.dart';
import '../utils/medication_safety_helper.dart';
import '../widgets/cds_badge.dart';
import '../widgets/course_management_sheet.dart';
import 'history_report_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'today_screen_add_course_fab',
        backgroundColor: cs.primary,
        elevation: 3,
        icon: Icon(Icons.add_rounded, color: cs.onPrimary, size: 20),
        label: Text(
          'Назначить курс',
          style: TextStyle(
            color: cs.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        onPressed: () => IntakeCourseWizard.show(context),
      ),
      body: SafeArea(
        child: state.isLoading
            ? Center(child: CircularProgressIndicator(color: cs.primary))
            : RefreshIndicator(
                color: cs.primary,
                onRefresh: () => state.refreshData(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    // 1. Top Header & Progress Badge
                    _buildHeader(context, state),
                    const SizedBox(height: 12),

                    // 2. Patient Selector Pills
                    _buildPatientSelector(context, state),
                    const SizedBox(height: 12),

                    // 3. Interactive Expandable Calendar (WeekStrip / MonthGrid)
                    const ExpandableCalendar(),
                    const SizedBox(height: 14),

                    // 4. Intakes List
                    _buildIntakeList(context, state),
                    const SizedBox(height: 72), // Space for FAB
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState state) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;
    final taken = state.takenIntakesCount;
    final total = state.totalIntakesCount;

    final selectedDate = state.selectedDate;
    final weekdays = [
      'ПОНЕДЕЛЬНИК',
      'ВТОРНИК',
      'СРЕДА',
      'ЧЕТВЕРГ',
      'ПЯТНИЦА',
      'СУББОТА',
      'ВОСКРЕСЕНЬЕ'
    ];
    final months = [
      'ЯНВАРЯ',
      'ФЕВРАЛЯ',
      'МАРТА',
      'АПРЕЛЯ',
      'МАЯ',
      'ИЮНЯ',
      'ИЮЛЯ',
      'АВГУСТА',
      'СЕНТЯБРЯ',
      'ОКТЯБРЯ',
      'НОЯБРЯ',
      'ДЕКАБРЯ'
    ];
    final todayTitle = '${weekdays[selectedDate.weekday - 1]}, ${selectedDate.day} ${months[selectedDate.month - 1]}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                todayTitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Расписание приёма',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => HistoryReportScreen.show(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎯', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(
                  '$taken / $total принято',
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 2),
        IconButton(
          icon: Icon(Icons.bar_chart_rounded, color: cs.primary, size: 22),
          tooltip: 'Отчёт для врача',
          onPressed: () => HistoryReportScreen.show(context),
        ),
        const SizedBox(width: 2),
        IconButton(
          icon: Badge(
            isLabelVisible: state.unreadNotificationsCount > 0,
            label: Text('${state.unreadNotificationsCount}'),
            backgroundColor: semantic.danger,
            child: Icon(Icons.notifications_outlined, color: cs.onSurface, size: 22),
          ),
          tooltip: 'Центр уведомлений',
          onPressed: () => NotificationCenterSheet.show(context),
        ),
      ],
    );
  }

  Widget _buildPatientSelector(BuildContext context, AppState state) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);
    final selectedProfile = state.selectedProfile;
    final hint = selectedProfile?.name ?? 'Вся семья';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ПАЦИЕНТ:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...state.profiles.map((profile) {
                final isSelected = state.selectedProfileId == profile.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: () => state.selectProfile(profile.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? cs.primary : cs.surface,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isSelected ? cs.primary : cs.outlineVariant,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: cs.shadow.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(profile.avatar, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          Text(
                            profile.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? cs.onPrimary : textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              // "Вся семья" pill
              InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: () => state.selectProfile(null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: state.selectedProfileId == null
                        ? cs.primary
                        : cs.surface,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: state.selectedProfileId == null
                          ? cs.primary
                          : cs.outlineVariant,
                    ),
                    boxShadow: state.selectedProfileId == null
                        ? [
                            BoxShadow(
                              color: cs.shadow.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👥', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(
                        'Вся семья',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: state.selectedProfileId == null
                              ? cs.onPrimary
                              : textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntakeList(BuildContext context, AppState state) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);
    final intakes = state.filteredIntakes;

    if (intakes.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(
              'На выбранный день приёмов нет!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Все запланированные лекарства приняты или список пуст.',
              style: TextStyle(fontSize: 11, color: textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () => IntakeCourseWizard.show(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Назначить курс приёма',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: intakes.map((item) {
        final profile = state.profiles.cast<Profile?>().firstWhere(
              (p) => p?.id == item.profileId,
              orElse: () => null,
            );

        if (item.isTaken) {
          return _buildTakenCard(context, state, item, profile);
        } else if (item.isSkipped) {
          return _buildSkippedCard(context, state, item, profile);
        } else if (item.isCurrent) {
          return _buildCurrentCard(context, state, item, profile);
        } else {
          return _buildUpcomingCard(context, state, item, profile);
        }
      }).toList(),
    );
  }

  // 1. Completed / Taken Intake Card
  Widget _buildTakenCard(
    BuildContext context,
    AppState state,
    IntakeLog item,
    Profile? profile,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: semantic.successBg,
              borderRadius: BorderRadius.circular(100),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.check_rounded,
              color: semantic.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.medicineName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    if (state.selectedProfileId == null && profile != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          profile.name,
                          style: TextStyle(
                            fontSize: 9,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.time} • ${item.rule}',
                  style: TextStyle(
                    fontSize: 10,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: semantic.successBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '✓ Принято',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: semantic.successText),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: Key('undo_intake_${item.id}'),
            icon: Icon(Icons.undo_rounded, size: 18, color: cs.primary),
            tooltip: 'Отменить приём',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _handleUndoIntake(context, state, item),
          ),
        ],
      ),
    );
  }

  // 2. Skipped Intake Card
  Widget _buildSkippedCard(
    BuildContext context,
    AppState state,
    IntakeLog item,
    Profile? profile,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(100),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.close_rounded,
              color: textMuted,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.medicineName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textMuted,
                        ),
                      ),
                    ),
                    if (state.selectedProfileId == null && profile != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          profile.name,
                          style: TextStyle(fontSize: 9, color: textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Пропущено: ${item.skippedReason ?? "Пользователем"}',
                  style: TextStyle(
                    fontSize: 10,
                    color: textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: state.isIntakeProcessing(item.id)
                ? null
                : () => _handleTakeIntake(context, state, item),
            child: state.isIntakeProcessing(item.id)
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Принять', style: TextStyle(fontSize: 11, color: cs.primary)),
          ),
        ],
      ),
    );
  }

  // 3. Current "СЕЙЧАС" Card
  Widget _buildCurrentCard(
    BuildContext context,
    AppState state,
    IntakeLog item,
    Profile? profile,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);
    final cdsAlert = MedicationSafetyHelper.evaluateSafety(
      log: item,
      allLogs: state.intakes,
      medicines: state.medicines,
      profile: profile,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current badge + profile name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'СЕЙЧАС (${item.time})',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (state.selectedProfileId == null && profile != null)
                Text(
                  '${profile.avatar} ${profile.name}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
            ],
          ),

          // CDS Warning Badge (Микро-спринт 11)
          if (cdsAlert != null) ...[
            const SizedBox(height: 8),
            CdsBadge(alert: cdsAlert),
          ],
          const SizedBox(height: 10),

          // Medicine Name + pill emoji
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.medicineName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.rule,
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Text('💊', style: TextStyle(fontSize: 24)),
            ],
          ),
          const SizedBox(height: 10),

          // Course and Stock deduct info box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => CourseManagementSheet.show(
                      context,
                      courseId: item.intakeCourseId ?? item.id,
                      courseTitle: item.course,
                      currentLog: item,
                      initialDosage: item.dosageQuantity,
                      initialInstruction: item.rule,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded, size: 12, color: cs.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Курс: ${item.course}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  'К списанию: ${item.formattedDosage}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Snoozed status indicator with Reset action (DEF-32)
          if (state.isSnoozed(item.id)) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 14, color: cs.onSecondaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        'Отложено на +15 мин',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () async {
                      await state.resetSnoozeIntake(item.id);
                      if (context.mounted) {
                        ToastHelper.show(
                          context,
                          message: 'Возвращено исходное время приёма',
                          icon: '⏱️',
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Вернуть исходное время',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action Buttons: Take, Snooze, Skip
          Row(
            children: [
              // 🟢 Take
              Expanded(
                flex: 4,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: state.isIntakeProcessing(item.id)
                      ? null
                      : () => _handleTakeIntake(context, state, item),
                  child: state.isIntakeProcessing(item.id)
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 14),
                            SizedBox(width: 4),
                            Text('Принято', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 6),

              // 🟡 Snooze (+15m)
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: textSecondary,
                    side: BorderSide(color: cs.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    state.snoozeIntake(item.id, minutes: 15);
                    ToastHelper.show(
                      context,
                      message: 'Напоминание отложено на 15 минут',
                      icon: '⏰',
                    );
                  },
                  child: const Text(
                    '+15м',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // ⚪ Skip
              Expanded(
                flex: 3,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: cs.surface,
                    foregroundColor: textSecondary,
                    side: BorderSide(color: cs.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final reason = await SkipReasonDialog.show(context, medicineName: item.medicineName);
                    if (reason != null) {
                      await state.skipIntake(item.id, reason: reason);
                      if (context.mounted) {
                        ToastHelper.show(
                          context,
                          message: 'Приём пропущен ($reason)',
                          icon: 'ℹ️',
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Пропустить',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. Upcoming / Scheduled Intake Card
  Widget _buildUpcomingCard(
    BuildContext context,
    AppState state,
    IntakeLog item,
    Profile? profile,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);
    final cdsAlert = MedicationSafetyHelper.evaluateSafety(
      log: item,
      allLogs: state.intakes,
      medicines: state.medicines,
      profile: profile,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.time,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.medicineName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        if (state.selectedProfileId == null && profile != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              profile.name,
                              style: TextStyle(
                                fontSize: 9,
                                color: textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.rule,
                      style: TextStyle(
                        fontSize: 11,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // CDS Warning Badge (Микро-спринт 11)
          if (cdsAlert != null) ...[
            const SizedBox(height: 8),
            CdsBadge(alert: cdsAlert),
          ],
          const SizedBox(height: 6),

          // Course and formatted dosage row
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => CourseManagementSheet.show(
              context,
              courseId: item.intakeCourseId ?? item.id,
              courseTitle: item.course,
              currentLog: item,
              initialDosage: item.dosageQuantity,
              initialInstruction: item.rule,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 11, color: cs.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Курс: ${item.course} • ${item.formattedDosage}',
                      style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Snoozed status indicator with Reset action (DEF-32)
          if (state.isSnoozed(item.id)) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 13, color: cs.onSecondaryContainer),
                      const SizedBox(width: 5),
                      Text(
                        'Отложено на +15 мин',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () async {
                      await state.resetSnoozeIntake(item.id);
                      if (context.mounted) {
                        ToastHelper.show(
                          context,
                          message: 'Возвращено исходное время приёма',
                          icon: '⏱️',
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Вернуть исходное время',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action row: 🟢 Принять, 🟡 +15м, ⚪ Пропустить
          Row(
            children: [
              // 🟢 Принять
              Expanded(
                flex: 4,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: state.isIntakeProcessing(item.id)
                      ? null
                      : () => _handleTakeIntake(context, state, item),
                  child: state.isIntakeProcessing(item.id)
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                        )
                      : const Text('Принять', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 6),

              // 🟡 +15м
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: textSecondary,
                    side: BorderSide(color: cs.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    state.snoozeIntake(item.id, minutes: 15);
                    ToastHelper.show(
                      context,
                      message: 'Напоминание отложено на 15 минут',
                      icon: '⏰',
                    );
                  },
                  child: const Text('+15м', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 6),

              // ⚪ Пропустить
              Expanded(
                flex: 3,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: cs.surface,
                    foregroundColor: textSecondary,
                    side: BorderSide(color: cs.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final reason = await SkipReasonDialog.show(context, medicineName: item.medicineName);
                    if (reason != null) {
                      await state.skipIntake(item.id, reason: reason);
                      if (context.mounted) {
                        ToastHelper.show(
                          context,
                          message: 'Приём пропущен ($reason)',
                          icon: 'ℹ️',
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Пропустить',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleTakeIntake(
    BuildContext context,
    AppState state,
    IntakeLog item,
  ) async {
    if (state.isIntakeProcessing(item.id)) return;

    try {
      final res = await state.takeIntakeLog(item.id);
      if (!context.mounted) return;
      if (res != null) {
        final message = res['message']?.toString() ?? '';
        if (message.contains('уже был зафиксирован ранее') || res['already_taken'] == true) {
          ToastHelper.show(
            context,
            message: 'Приём лекарства уже был зафиксирован ранее.',
            icon: 'ℹ️',
          );
        } else {
          ToastHelper.show(
            context,
            message: 'Принято: ${item.medicineName}. Остаток в аптечке обновлён!',
            icon: '💊',
          );
        }
      }
    } on StockConfirmationRequiredException catch (e) {
      if (!context.mounted) return;
      final result = await OutOfStockConfirmationDialog.show(
        context,
        medicineName: item.medicineName,
        remainingQuantity: e.remainingQuantity,
      );
      if (!context.mounted) return;
      if (result == OutOfStockDialogResult.addToShopping) {
        state.addToShoppingList(
          item.medicineName,
          quantity: 1,
          dosage: item.form,
        );
        ToastHelper.show(
          context,
          message: '«${item.medicineName}» добавлен в список покупок',
          icon: '🛒',
        );
      } else if (result == OutOfStockDialogResult.confirmIntake) {
        try {
          await state.takeIntakeLog(item.id, confirmWithoutStock: true);
          if (context.mounted) {
            ToastHelper.show(
              context,
              message: 'Приём зафиксирован без списания остатка',
              icon: '💊',
            );
          }
        } catch (err) {
          if (context.mounted) {
            final friendly = ApiErrorHandler.format(err, defaultMessage: 'Не удалось подтвердить списание остатка');
            ToastHelper.show(
              context,
              message: friendly,
              icon: '⚠️',
              isError: true,
              onRetry: () => _handleTakeIntake(context, state, item),
            );
          }
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      final friendly = ApiErrorHandler.format(e, defaultMessage: 'Не удалось зафиксировать приём: проверьте подключение к сети');
      ToastHelper.show(
        context,
        message: friendly,
        icon: '⚠️',
        isError: true,
        onRetry: () => _handleTakeIntake(context, state, item),
      );
    }
  }

  Future<void> _handleUndoIntake(BuildContext context, AppState state, IntakeLog item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Отмена приёма'),
        content: Text(
          'Вы действительно хотите отменить приём «${item.medicineName}» и вернуть препарат на остаток?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const Key('confirm_undo_button'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Вернуть приём'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final res = await state.undoIntake(item.id);
        if (context.mounted) {
          final msg = res?['message']?.toString() ?? 'Приём отменён, остаток восстановлен.';
          ToastHelper.show(
            context,
            message: msg,
            icon: '↩️',
          );
        }
      } catch (e) {
        if (context.mounted) {
          final friendly = ApiErrorHandler.format(e, defaultMessage: 'Не удалось отменить приём: проверьте подключение к сети');
          ToastHelper.show(
            context,
            message: friendly,
            icon: '⚠️',
            isError: true,
            onRetry: () => _handleUndoIntake(context, state, item),
          );
        }
      }
    }
  }
}
