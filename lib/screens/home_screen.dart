import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_center_sheet.dart';
import 'today_screen.dart';
import 'medicine_box_screen.dart';
import 'notes_screen.dart';
import 'family_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Семейная Аптечка'),
        actions: [
          Consumer<AppState>(
            builder: (context, appState, child) {
              final unreadCount = appState.unreadNotificationsCount;
              return IconButton(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  backgroundColor: const Color(0xFFEF4444),
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: 'Уведомления',
                onPressed: () => NotificationCenterSheet.show(context),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: state.activeTabIndex,
        children: const [
          TodayScreen(),
          MedicineBoxScreen(),
          NotesScreen(),
          FamilyScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, state),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, AppState state) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.event_note_rounded,
            label: 'Сегодня',
            isSelected: state.activeTabIndex == 0,
            onTap: () => state.setTab(0),
          ),
          _buildNavItem(
            icon: Icons.medication_rounded,
            label: 'Аптечка',
            isSelected: state.activeTabIndex == 1,
            onTap: () => state.setTab(1),
          ),
          _buildNavItem(
            icon: Icons.receipt_long_rounded,
            label: 'Заметки',
            isSelected: state.activeTabIndex == 2,
            onTap: () => state.setTab(2),
          ),
          _buildNavItem(
            icon: Icons.people_alt_rounded,
            label: 'Семья',
            isSelected: state.activeTabIndex == 3,
            onTap: () => state.setTab(3),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 3,
                width: isSelected ? 20 : 0,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                icon,
                size: 22,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
