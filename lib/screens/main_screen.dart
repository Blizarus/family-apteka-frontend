import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'today_screen.dart';
import 'medicine_box_screen.dart';
import 'notes_screen.dart';
import 'family_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Responsive shell: on wide screens, center a phone mockup container (Health-Tech Minimal),
    // on narrow screens (e.g. mobile), use full screen.
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 520;

        Widget appContent = Scaffold(
          backgroundColor: AppColors.background,
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
          backgroundColor: const Color(0xFF0F172A), // Slate 900
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
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2DD4BF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const Flexible(
                                child: Text(
                                  'Семейная Аптечка',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Health-Tech Minimal',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
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
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(44),
                      border: Border.all(color: const Color(0xFF334155), width: 8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
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
                          color: AppColors.background,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '09:41',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '5G',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '100%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
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
