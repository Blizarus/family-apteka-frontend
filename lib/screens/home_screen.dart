import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../widgets/notification_center_sheet.dart';
import '../widgets/notification_permission_dialog.dart';
import 'today_screen.dart';
import 'medicine_box_screen.dart';
import 'notes_screen.dart';
import 'family_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final apiService = context.read<ApiService>();
        if (!apiService.isMockMode) {
          NotificationPermissionDialog.showIfNeeded(
            context,
            storageService: apiService.storageService,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                  backgroundColor: colorScheme.error,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant, width: 1)),
      ),
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            context: context,
            icon: Icons.event_note_rounded,
            label: 'Сегодня',
            isSelected: state.activeTabIndex == 0,
            onTap: () => state.setTab(0),
          ),
          _buildNavItem(
            context: context,
            icon: Icons.medication_rounded,
            label: 'Аптечка',
            isSelected: state.activeTabIndex == 1,
            onTap: () => state.setTab(1),
          ),
          _buildNavItem(
            context: context,
            icon: Icons.receipt_long_rounded,
            label: 'Заметки',
            isSelected: state.activeTabIndex == 2,
            onTap: () => state.setTab(2),
          ),
          _buildNavItem(
            context: context,
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
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unselectedColor = theme.textTheme.bodySmall?.color ?? colorScheme.onSurface.withValues(alpha: 0.5);

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
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                icon,
                size: 22,
                color: isSelected ? colorScheme.primary : unselectedColor,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? colorScheme.primary : unselectedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
