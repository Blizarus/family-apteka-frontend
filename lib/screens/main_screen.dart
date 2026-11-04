import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../widgets/notification_permission_dialog.dart';
import 'today_screen.dart';
import 'medicine_box_screen.dart';
import 'notes_screen.dart';
import 'family_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 520;

        Widget appContent = Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
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

        if (!isDesktop) {
          return appContent;
        }

        // Desktop Preview Mockup matching app_prototype.html
        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Title / Badge info
                  Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  'Семейная Аптечка',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Health-Tech Minimal',
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color ?? colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Phone Frame
                  Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    width: double.infinity,
                    height: 840,
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(44),
                      border: Border.all(color: colorScheme.outlineVariant, width: 8),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.15),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Simulated Status Bar
                        Container(
                          color: theme.scaffoldBackgroundColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '09:41',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textTheme.bodyMedium?.color ?? colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '5G',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textTheme.bodySmall?.color ?? colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '100%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textTheme.bodyMedium?.color ?? colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Screen body
                        Expanded(child: appContent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
