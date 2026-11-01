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

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'today_screen_add_course_fab',
        backgroundColor: AppColors.primary,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: const Text(
          'Назначить курс',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        onPressed: () => IntakeCourseWizard.show(context),
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                color: AppColors.primary,
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
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.primaryHover,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Расписание приёма',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎯', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                '$taken / $total принято',
                style: const TextStyle(
                  color: AppColors.primaryDeep,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Badge(
            isLabelVisible: state.unreadNotificationsCount > 0,
            label: Text('${state.unreadNotificationsCount}'),
            backgroundColor: const Color(0xFFEF4444),
            child: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 22),
          ),
          tooltip: 'Центр уведомлений',
          onPressed: () => NotificationCenterSheet.show(context),
        ),
      ],
    );
  }

  Widget _buildPatientSelector(BuildContext context, AppState state) {
    final selectedProfile = state.selectedProfile;
    final hint = selectedProfile?.name ?? 'Вся семья';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ПАЦИЕНТ:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryHover,
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
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
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
                              color: isSelected ? Colors.white : AppColors.textSecondary,
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
                        ? AppColors.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: state.selectedProfileId == null
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                    boxShadow: state.selectedProfileId == null
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
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
                              ? Colors.white
                              : AppColors.textSecondary,
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
    final intakes = state.filteredIntakes;

    if (intakes.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            const Text(
              'На выбранный день приёмов нет!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Все запланированные лекарства приняты или список пуст.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE6FFFA),
              borderRadius: BorderRadius.circular(100),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.primaryHover,
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
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    if (state.selectedProfileId == null && profile != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          profile.name,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.time} • ${item.rule}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '✓ Принято',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryDeep),
            ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(100),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.close_rounded,
              color: Color(0xFF94A3B8),
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
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    if (state.selectedProfileId == null && profile != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          profile.name,
                          style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Пропущено: ${item.skippedReason ?? "Пользователем"}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
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
            onPressed: () {
              state.markIntakeTaken(item.id);
              ToastHelper.show(context, message: 'Приём зафиксирован!', icon: '💊');
            },
            child: const Text('Принять', style: TextStyle(fontSize: 11, color: AppColors.primaryHover)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
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
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'СЕЙЧАС (${item.time})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (state.selectedProfileId == null && profile != null)
                Text(
                  '${profile.avatar} ${profile.name}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryHover,
                  ),
                ),
            ],
          ),
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.rule,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
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
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Курс: ${item.course}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Остаток спишется: -${item.dosageQuantity > 0 ? item.dosageQuantity : 1} ${item.unit.isNotEmpty ? item.unit : "табл."}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryHover,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons: Take, Snooze, Skip
          Row(
            children: [
              // 🟢 Take
              Expanded(
                flex: 4,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    state.markIntakeTaken(item.id);
                    ToastHelper.show(
                      context,
                      message: 'Принято: ${item.medicineName}. Остаток в аптечке обновлён!',
                      icon: '💊',
                    );
                  },
                  child: const Row(
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
                    backgroundColor: AppColors.surfaceSubtle,
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
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
                    backgroundColor: AppColors.background,
                    foregroundColor: Colors.grey.shade700,
                    side: const BorderSide(color: AppColors.border),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.time,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
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
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (state.selectedProfileId == null && profile != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              profile.name,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.rule,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Action row: 🟢 Принять, 🟡 +15м, ⚪ Пропустить
          Row(
            children: [
              // 🟢 Принять
              Expanded(
                flex: 4,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    state.markIntakeTaken(item.id);
                    ToastHelper.show(
                      context,
                      message: 'Принято: ${item.medicineName}. Остаток в аптечке обновлён!',
                      icon: '💊',
                    );
                  },
                  child: const Text('Принять', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 6),

              // 🟡 +15м
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surfaceSubtle,
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
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
                    backgroundColor: AppColors.background,
                    foregroundColor: Colors.grey.shade700,
                    side: const BorderSide(color: AppColors.border),
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
}
