import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/add_medicine_sheet.dart';
import '../widgets/medicine_details_sheet.dart';
import '../widgets/traffic_light_badge.dart';
import '../widgets/box_selector_dialog.dart';

class MedicineBoxScreen extends StatefulWidget {
  const MedicineBoxScreen({super.key});

  @override
  State<MedicineBoxScreen> createState() => _MedicineBoxScreenState();
}

class _MedicineBoxScreenState extends State<MedicineBoxScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currentBox = state.selectedBox;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppDarkColors.background : AppColors.background;
    final surface = isDark ? AppDarkColors.surface : Colors.white;
    final border = isDark ? AppDarkColors.border : AppColors.border;
    final textPrimary = isDark ? AppDarkColors.textPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppDarkColors.textSecondary : AppColors.textSecondary;
    final textMuted = isDark ? AppDarkColors.textMuted : AppColors.textMuted;
    final surfaceSubtle = isDark ? AppDarkColors.surfaceSubtle : AppColors.surfaceSubtle;

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'med_box_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Добавить препарат',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        onPressed: () => AddMedicineSheet.show(context),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => state.refreshData(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Header with Storage Box Selector Dropdown
              _buildHeader(context, currentBox, isDark, textPrimary, textSecondary, textMuted, surfaceSubtle),
              const SizedBox(height: 12),

              // 2. Search Field
              _buildSearchField(state, isDark, surface, border, textPrimary, textMuted),
              const SizedBox(height: 12),

              // 3. Traffic Light Filter Buttons
              _buildTrafficLightFilters(state, isDark, surface, border, textPrimary, textSecondary),
              const SizedBox(height: 14),

              // 4. Medicine List
              _buildMedicineList(context, state, isDark, surface, border, textPrimary, textSecondary, textMuted),
              const SizedBox(height: 60), // Spacing for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic currentBox, bool isDark, Color textPrimary, Color textSecondary, Color textMuted, Color surfaceSubtle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ИНВЕНТАРЬ АПТЕЧКИ',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: isDark ? AppDarkColors.primary : AppColors.primaryHover,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => BoxSelectorSheet.show(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentBox?.name ?? 'Домашняя аптечка',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: surfaceSubtle,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '▼',
                    style: TextStyle(
                      fontSize: 10,
                      color: textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Text(
          currentBox?.location ?? 'Шкаф в коридоре (полка 2)',
          style: TextStyle(
            fontSize: 11,
            color: textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(AppState state, bool isDark, Color surface, Color border, Color textPrimary, Color textMuted) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(fontSize: 12, color: textPrimary),
        onChanged: (val) => state.setSearchQuery(val),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.transparent,
          hintText: 'Поиск по названию или веществу...',
          hintStyle: TextStyle(fontSize: 12, color: textMuted),
          prefixIcon: Icon(Icons.search, size: 18, color: textMuted),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 16, color: textMuted),
                  onPressed: () {
                    _searchController.clear();
                    state.setSearchQuery('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
      ),
    );
  }

  Widget _buildTrafficLightFilters(AppState state, bool isDark, Color surface, Color border, Color textPrimary, Color textSecondary) {
    final expiringBg = isDark ? AppDarkColors.statusExpiringBg : AppColors.statusExpiringBg;
    final expiringBorder = isDark ? AppDarkColors.statusExpiringBorder : AppColors.statusExpiringBorder;
    final expiringText = isDark ? AppDarkColors.statusExpiringText : AppColors.statusExpiringText;
    final expiredBg = isDark ? AppDarkColors.statusExpiredBg : AppColors.statusExpiredBg;
    final expiredBorder = isDark ? AppDarkColors.statusExpiredBorder : AppColors.statusExpiredBorder;
    final expiredText = isDark ? AppDarkColors.statusExpiredText : AppColors.statusExpiredText;

    return Row(
      children: [
        // 1. All
        Expanded(
          child: _buildFilterCard(
            label: 'Все',
            count: '${state.countAllMedicines} шт.',
            isSelected: state.medicineFilter == 'all',
            bgColor: surface,
            selectedBorderColor: isDark ? AppDarkColors.primary : AppColors.primary,
            unselectedBorderColor: border,
            textColor: textPrimary,
            onTap: () => state.setMedicineFilter('all'),
          ),
        ),
        const SizedBox(width: 8),

        // 2. Expiring
        Expanded(
          child: _buildFilterCard(
            label: 'Истекают',
            count: '${state.countExpiringMedicines} шт.',
            isSelected: state.medicineFilter == 'expiring',
            bgColor: expiringBg,
            selectedBorderColor: expiringText,
            unselectedBorderColor: expiringBorder,
            textColor: expiringText,
            onTap: () => state.setMedicineFilter('expiring'),
          ),
        ),
        const SizedBox(width: 8),

        // 3. Expired
        Expanded(
          child: _buildFilterCard(
            label: 'Просрочены',
            count: '${state.countExpiredMedicines} шт.',
            isSelected: state.medicineFilter == 'expired',
            bgColor: expiredBg,
            selectedBorderColor: expiredText,
            unselectedBorderColor: expiredBorder,
            textColor: expiredText,
            onTap: () => state.setMedicineFilter('expired'),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterCard({
    required String label,
    required String count,
    required bool isSelected,
    required Color bgColor,
    required Color selectedBorderColor,
    required Color unselectedBorderColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? selectedBorderColor : unselectedBorderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: textColor.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              count,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineList(BuildContext context, AppState state, bool isDark, Color surface, Color border, Color textPrimary, Color textSecondary, Color textMuted) {
    final list = state.filteredMedicines;

    if (list.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            const Text('🔍', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              'Ничего не найдено',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Попробуйте изменить поисковый запрос или фильтр.',
              style: TextStyle(fontSize: 10, color: textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: list.map((m) {
        Color borderColor = border;
        Color expiryColor = textSecondary;

        if (m.isExpiring) {
          borderColor = isDark ? AppDarkColors.statusExpiringBorder : AppColors.statusExpiringBorder;
          expiryColor = isDark ? AppDarkColors.statusExpiringText : AppColors.statusExpiringText;
        } else if (m.isExpired) {
          borderColor = isDark ? AppDarkColors.statusExpiredBorder : AppColors.statusExpiredBorder;
          expiryColor = isDark ? AppDarkColors.statusExpiredText : AppColors.statusExpiredText;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => MedicineDetailsSheet.show(context, medicine: m),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  m.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              if (m.isPrescription) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Rx',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (m.substance.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Действ. в-во: ${m.substance}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 3),
                          Text(
                            'Срок: ${m.expiry}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: m.isOk ? FontWeight.w500 : FontWeight.w700,
                              color: expiryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${m.remainingDisplay} / ${m.totalDisplay} шт.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TrafficLightBadge(status: m.status),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
