import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/intake_log.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class ExpandableCalendar extends StatefulWidget {
  const ExpandableCalendar({super.key});

  @override
  State<ExpandableCalendar> createState() => _ExpandableCalendarState();
}

class _ExpandableCalendarState extends State<ExpandableCalendar> {
  static const int _kInitialPage = 1000;
  static const List<String> _months = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь'
  ];
  static const List<String> _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  late final PageController _pageController;
  late final DateTime _baseMonday;
  late DateTime _displayMonth;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _baseMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    _pageController = PageController(initialPage: _kInitialPage);
    _displayMonth = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _scrollToToday(AppState state) {
    final now = DateTime.now();
    state.selectCalendarDate(now);
    setState(() {
      _displayMonth = DateTime(now.year, now.month, 1);
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        _kInitialPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        final selected = context.read<AppState>().selectedDate;
        _displayMonth = DateTime(selected.year, selected.month, 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selectedDate = state.selectedDate;
    final now = DateTime.now();
    final isTodaySelected = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 250 && !_isExpanded) {
            _toggleExpanded();
          } else if (details.primaryVelocity! < -250 && _isExpanded) {
            _toggleExpanded();
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top control bar
            _buildControlBar(state, isTodaySelected),
            const SizedBox(height: 8),

            // Animated body: WeekStrip or MonthGrid
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 260),
              crossFadeState:
                  _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: _buildWeekStrip(state),
              secondChild: _buildMonthGrid(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar(AppState state, bool isTodaySelected) {
    final displayDate = _isExpanded ? _displayMonth : state.selectedDate;
    final monthYearText =
        '${_months[displayDate.month - 1]} ${displayDate.year}'.toUpperCase();

    if (_isExpanded) {
      return Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: AppColors.textPrimary,
            onPressed: () {
              setState(() {
                _displayMonth =
                    DateTime(_displayMonth.year, _displayMonth.month - 1, 1);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: AppColors.textPrimary,
            onPressed: () {
              setState(() {
                _displayMonth =
                    DateTime(_displayMonth.year, _displayMonth.month + 1, 1);
              });
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              monthYearText,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Collapse button
          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: _toggleExpanded,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Today quick-jump pill
        InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: () => _scrollToToday(state),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isTodaySelected
                  ? AppColors.primarySurface
                  : AppColors.background,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isTodaySelected
                    ? AppColors.primaryBorder
                    : AppColors.border,
              ),
            ),
            child: Text(
              '◎ Сегодня',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isTodaySelected
                    ? AppColors.primaryDeep
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),

        Text(
          monthYearText,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.primaryHover,
          ),
        ),

        // Expand button
        InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: _toggleExpanded,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekStrip(AppState state) {
    return SizedBox(
      height: 72,
      child: PageView.builder(
        controller: _pageController,
        itemBuilder: (context, pageIndex) {
          final weekMonday =
              _baseMonday.add(Duration(days: (pageIndex - _kInitialPage) * 7));
          final days = List.generate(7, (i) => weekMonday.add(Duration(days: i)));

          return Row(
            children: days.map((dayDate) {
              return Expanded(
                child: _buildDayCell(
                  state: state,
                  dayDate: dayDate,
                  isSelected: _isSameDay(dayDate, state.selectedDate),
                  isToday: _isSameDay(dayDate, DateTime.now()),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildDayCell({
    required AppState state,
    required DateTime dayDate,
    required bool isSelected,
    required bool isToday,
  }) {
    final weekdayLabel = _weekdays[dayDate.weekday - 1];
    final dayIntakes = state.getIntakesForDate(dayDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => state.selectCalendarDate(dayDate),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isToday ? AppColors.primarySurface : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isToday ? AppColors.primaryBorder : AppColors.border),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdayLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.primaryBorderLight
                      : (isToday ? AppColors.primaryDeep : AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dayDate.day.toString(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : (isToday ? AppColors.primaryDeep : AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 4),
              // Up to 3 indicator dots
              _buildIntakeDots(dayIntakes, isSelected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntakeDots(List<IntakeLog> dayIntakes, bool isSelected) {
    if (dayIntakes.isEmpty) {
      return const SizedBox(height: 5);
    }

    final shownIntakes = dayIntakes.take(3).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: shownIntakes.map((log) {
        Color dotColor;
        BoxBorder? border;

        if (log.isTaken) {
          dotColor = isSelected ? Colors.white : const Color(0xFF10B981); // Green
        } else if (log.isSkipped) {
          dotColor = isSelected ? const Color(0xFFFECDD3) : Colors.white;
          border = Border.all(
            color: isSelected ? Colors.white : AppColors.accentCoral,
            width: 1.2,
          );
        } else {
          // Scheduled
          dotColor = isSelected ? Colors.white.withValues(alpha: 0.6) : const Color(0xFFCBD5E1);
        }

        return Container(
          width: 4.5,
          height: 4.5,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: border,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthGrid(AppState state) {
    final firstDayOfMonth = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final daysInMonth =
        DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;
    final leadingEmptyCount = firstDayOfMonth.weekday - 1; // 0 for Mon, 6 for Sun
    final totalCells = leadingEmptyCount + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Column(
      children: [
        // 7 Weekday Headers
        Row(
          children: _weekdays.map((w) {
            return Expanded(
              child: Center(
                child: Text(
                  w,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),

        // Grid rows
        ...List.generate(rowCount, (rowIndex) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: List.generate(7, (colIndex) {
                final cellIndex = rowIndex * 7 + colIndex;
                final dayNumber = cellIndex - leadingEmptyCount + 1;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 32));
                }

                final dayDate = DateTime(
                    _displayMonth.year, _displayMonth.month, dayNumber);
                final isSelected = _isSameDay(dayDate, state.selectedDate);
                final isToday = _isSameDay(dayDate, DateTime.now());
                final dayIntakes = state.getIntakesForDate(dayDate);

                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => state.selectCalendarDate(dayDate),
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isToday ? AppColors.primarySurface : Colors.transparent),
                        borderRadius: BorderRadius.circular(8),
                        border: isToday && !isSelected
                            ? Border.all(color: AppColors.primaryBorder)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayNumber.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isToday
                                      ? AppColors.primaryDeep
                                      : AppColors.textPrimary),
                            ),
                          ),
                          const SizedBox(height: 2),
                          _buildMonthHeatmapDot(dayIntakes, isSelected),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMonthHeatmapDot(List<IntakeLog> intakes, bool isSelected) {
    if (intakes.isEmpty) {
      return const SizedBox(height: 3.5);
    }

    final takenCount = intakes.where((i) => i.isTaken).length;
    final total = intakes.length;
    final ratio = takenCount / total;

    Color color;
    if (ratio == 1.0) {
      color = isSelected ? Colors.white : const Color(0xFF10B981); // 100% green
    } else if (ratio >= 0.5) {
      color = isSelected ? const Color(0xFFFDE68A) : const Color(0xFFF59E0B); // Amber
    } else {
      color = isSelected ? const Color(0xFFFECDD3) : AppColors.accentCoral; // Coral
    }

    return Container(
      width: 3.5,
      height: 3.5,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
