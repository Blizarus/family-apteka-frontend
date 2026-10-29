import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/medical_note.dart';
import '../models/medicine.dart';
import '../models/profile.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/add_note_sheet.dart';
import '../widgets/intake_course_wizard.dart';
import '../widgets/swipeable_prescription_card.dart';
import '../widgets/toast_helper.dart';
import 'shopping_list_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newShoppingItemController = TextEditingController();
  String _activeFilter = 'active'; // 'active', 'archived', 'dictated', 'shopping'
  String _searchQuery = '';
  bool _isSnackBarActive = false;

  @override
  void dispose() {
    _searchController.dispose();
    _newShoppingItemController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    const months = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    return '$day $month $year';
  }

  String _getSpecialtyIcon(String specialty) {
    switch (specialty.toLowerCase()) {
      case 'терапевт':
        return '🩺';
      case 'педиатр':
        return '👶';
      case 'лор':
      case 'отоларинголог':
        return '👂';
      case 'кардиолог':
        return '❤️';
      case 'невролог':
        return '🧠';
      case 'гастроэнтеролог':
        return '🥗';
      case 'офтальмолог':
        return '👁️';
      case 'стоматолог':
        return '🦷';
      default:
        return '👨‍⚕️';
    }
  }

  // -------------------------------------------------------------
  // ACCIDENTAL ACTION PROTECTION (7-SECOND UNDO SNACKBAR)
  // -------------------------------------------------------------
  void _showUndoSnackBar({
    required String message,
    required VoidCallback onUndo,
  }) {
    if (!mounted) return;
    setState(() => _isSnackBarActive = true);

    ScaffoldMessenger.of(context).clearSnackBars();
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 7), // 7-секундное окно отмены
        elevation: 6,
        backgroundColor: const Color(0xFF0F172A), // Slate 900
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 72),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const Text('📋', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: '↩️ Отмена',
          textColor: const Color(0xFF2DD4BF), // Bright Teal
          onPressed: () {
            onUndo();
            ToastHelper.show(
              context,
              message: 'Действие отменено, карточка восстановлена!',
              icon: '↩️',
            );
          },
        ),
      ),
    );

    controller.closed.then((_) {
      if (mounted) {
        setState(() => _isSnackBarActive = false);
      }
    });
  }

  void _archiveNote(MedicalNote note, int index) {
    final state = context.read<AppState>();
    state.archiveNote(note.id);

    _showUndoSnackBar(
      message: 'Назначение от ${note.doctorName} перенесено в архив',
      onUndo: () {
        state.unarchiveNote(note.id);
      },
    );
  }

  void _deleteNote(MedicalNote note, int index) {
    final state = context.read<AppState>();
    state.deleteNote(note.id);

    _showUndoSnackBar(
      message: 'Назначение «${note.diagnosis}» удалено',
      onUndo: () {
        state.restoreNote(note, index);
      },
    );
  }

  void _confirmDeleteNote(BuildContext context, MedicalNote note, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🗑️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Удалить назначение?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Вы уверены, что хотите удалить запись от ${note.doctorName} (${note.diagnosis})?',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBE123C),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteNote(note, index);
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: AnimatedPadding(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        // Смещаем кнопку наверх при появлении SnackBar, чтобы он физически не перекрывал экшн-бар
        padding: EdgeInsets.only(bottom: _isSnackBarActive ? 68.0 : 0.0),
        child: FloatingActionButton.extended(
          heroTag: 'notes_screen_fab',
          backgroundColor: AppColors.primary,
          elevation: 3,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          label: const Text(
            'Новое назначение',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          onPressed: () => AddNoteSheet.show(context),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => state.refreshData(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Header
              _buildHeader(context, state),
              const SizedBox(height: 12),

              // 2. Patient Selector Pills
              _buildPatientSelector(context, state),
              const SizedBox(height: 12),

              // 3. Search Bar
              _buildSearchBar(),
              const SizedBox(height: 10),

              // 4. Filter Chips
              _buildFilterChips(state),
              const SizedBox(height: 14),

              // 5. Content: Shopping List or Notes List
              if (_activeFilter == 'shopping')
                _buildShoppingListView(context, state)
              else
                _buildNotesList(context, state),

              const SizedBox(height: 90), // Padding for FAB & SnackBar space
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState state) {
    final activeCount = state.activeNotes.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Заметки и рецепты',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Назначения врачей и синхронизация с аптечкой',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
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
              const Text('📝', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                '$activeCount активных',
                style: const TextStyle(
                  color: AppColors.primaryDeep,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
              // All Family pill
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
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
                        const Text('👨‍👩‍👦', style: TextStyle(fontSize: 13)),
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
              ),

              // Individual Profiles
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() => _searchQuery = val.trim().toLowerCase());
        },
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Поиск по врачу, диагнозу, лекарству...',
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
      ),
    );
  }

  Widget _buildFilterChips(AppState state) {
    final activeCount = state.activeNotes.length;
    final archivedCount = state.archivedNotes.length;
    final shoppingCount = state.shoppingItems.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(
            id: 'active',
            label: 'Активные',
            count: activeCount,
          ),
          const SizedBox(width: 6),
          _buildChip(
            id: 'archived',
            label: '📁 Архив',
            count: archivedCount,
          ),
          const SizedBox(width: 6),
          _buildChip(
            id: 'dictated',
            label: '🎙️ Диктовка',
            count: state.filteredNotes.where((n) => n.isAudioDictated).length,
          ),
          const SizedBox(width: 6),
          _buildChip(
            id: 'shopping',
            label: '🛒 В аптеку',
            count: shoppingCount,
            highlightColor: shoppingCount > 0 ? AppColors.statusExpiringText : null,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String id,
    required String label,
    int? count,
    Color? highlightColor,
  }) {
    final isSelected = _activeFilter == id;

    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: () => setState(() => _activeFilter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (highlightColor ?? AppColors.textSecondary),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList(BuildContext context, AppState state) {
    var notes = state.filteredNotes;

    // Filter by Active vs Archived vs Dictated
    if (_activeFilter == 'active') {
      notes = notes.where((n) => !n.isArchived).toList();
    } else if (_activeFilter == 'archived') {
      notes = notes.where((n) => n.isArchived).toList();
    } else if (_activeFilter == 'dictated') {
      notes = notes.where((n) => n.isAudioDictated).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      notes = notes.where((n) {
        final matchesDoctor = n.doctorName.toLowerCase().contains(_searchQuery);
        final matchesClinic = n.clinic.toLowerCase().contains(_searchQuery);
        final matchesDiag = n.diagnosis.toLowerCase().contains(_searchQuery);
        final matchesContent = n.content.toLowerCase().contains(_searchQuery);
        final matchesMeds = n.prescribedMedicines
            .any((m) => m.name.toLowerCase().contains(_searchQuery));
        return matchesDoctor ||
            matchesClinic ||
            matchesDiag ||
            matchesContent ||
            matchesMeds;
      }).toList();
    }

    // -------------------------------------------------------------
    // EMPTY STATE (P1 UX Requirement)
    // -------------------------------------------------------------
    if (notes.isEmpty) {
      final isArchivedTab = _activeFilter == 'archived';
      return Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isArchivedTab
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFFF0FDFA), // Teal 50
                shape: BoxShape.circle,
                border: Border.all(
                  color: isArchivedTab
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF99F6E4),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                isArchivedTab ? '📁' : '🎉',
                style: const TextStyle(fontSize: 30),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isArchivedTab ? 'Архив пуст' : 'Все назначения выполнены',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isArchivedTab
                  ? 'Здесь будут храниться завершенные курсы лечения и рецепты, отправленные в архив.'
                  : 'Активных предписаний врача нет. Завершенные курсы доступны во вкладке «Архив».',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              ),
              onPressed: () => AddNoteSheet.show(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Новое назначение',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: notes.asMap().entries.map((entry) {
        final index = entry.key;
        final note = entry.value;

        // Custom Swipeable Prescription Card (NOT Dismissible!)
        return SwipeablePrescriptionCard(
          key: ValueKey('note_${note.id}'),
          onArchive: () => _archiveNote(note, index),
          onDelete: () => _confirmDeleteNote(context, note, index),
          child: _buildNoteCard(context, state, note, index),
        );
      }).toList(),
    );
  }

  Widget _buildNoteCard(
    BuildContext context,
    AppState state,
    MedicalNote note,
    int index,
  ) {
    Profile? noteProfile;
    try {
      noteProfile = state.profiles.firstWhere((p) => p.id == note.profileId);
    } catch (_) {
      noteProfile = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Card Top: Specialty Badge, Clinic, Date, Options
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Specialty pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getSpecialtyIcon(note.specialty),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        note.specialty,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Clinic & Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.clinic,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _formatDate(note.date),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                if (note.isArchived)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Text(
                      'В архиве',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),

                // Quick popup / delete button
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  tooltip: 'Удалить запись',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _confirmDeleteNote(context, note, index),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: AppColors.border),

          // 2. Doctor, Diagnosis & Patient Tag
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Врач: ${note.doctorName}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (noteProfile != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(noteProfile.avatar, style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 4),
                            Text(
                              noteProfile.name,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),

                // Diagnosis pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderDarker),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🩺', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Диагноз: ${note.diagnosis}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                if (note.isAudioDictated) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF), // Blue 50
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)), // Blue 200
                    ),
                    child: const Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('🎙️', style: TextStyle(fontSize: 11)),
                        SizedBox(width: 5),
                        Text(
                          'Надиктовано голосом врача (распознано ИИ)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D4ED8), // Blue 700
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 3. Clinical Instructions Box
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              note.content,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ),

          // 4. Smart Medicine Matching Section (Traffic-Light Badge)
          if (note.prescribedMedicines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'СОПОСТАВЛЕНИЕ С АПТЕЧКОЙ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppColors.textMuted,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text('•', style: TextStyle(color: AppColors.textMuted)),
                      SizedBox(width: 6),
                      Text(
                        'Светофор запасов',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primaryHover,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...note.prescribedMedicines.map(
                    (item) => _buildPrescribedMedicineRow(context, state, item, note: note),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildPrescribedMedicineRow(
    BuildContext context,
    AppState state,
    PrescribedMedicineItem item, {
    MedicalNote? note,
  }) {
    Color bg;
    Color border;
    Color textColor;
    String statusIcon;
    String statusText;

    if (item.isInStock) {
      bg = AppColors.statusOkBg;
      border = const Color(0xFFA7F3D0);
      textColor = AppColors.statusOkText;
      statusIcon = '🟢';
      statusText = '✓ В аптечке: ${item.remainingCount} шт. (${item.locationInfo})';
    } else if (item.isLowStock) {
      bg = AppColors.statusExpiringBg;
      border = AppColors.statusExpiringBorder;
      textColor = AppColors.statusExpiringText;
      statusIcon = '🟡';
      statusText =
          'Мало: ${item.remainingCount} шт. (требуется ${item.neededCount} шт.)';
    } else {
      bg = AppColors.statusExpiredBg;
      border = AppColors.statusExpiredBorder;
      textColor = AppColors.statusExpiredText;
      statusIcon = '🔴';
      statusText = 'Отсутствует в аптечке';
    }

    final isInShoppingList =
        state.shoppingList.any((name) => name.toLowerCase().contains(item.name.toLowerCase()));

    final matchedMed = state.medicines.cast<Medicine?>().firstWhere(
          (m) =>
              m != null &&
              (m.name.toLowerCase().contains(item.name.toLowerCase()) ||
                  item.name.toLowerCase().contains(m.name.toLowerCase())),
          orElse: () => null,
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(statusIcon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    if (item.dosage.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${item.dosage})',
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: textColor.withValues(alpha: 0.9),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (item.isInStock) ...[
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                IntakeCourseWizard.show(
                  context,
                  initialMedicine: matchedMed,
                  initialMedicineName: item.name,
                  initialProfileId: note?.profileId,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 2),
                    Text(
                      'Назначить',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!item.isInStock) ...[
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                // Deduplication: checks presence, merges quantities
                state.addToShoppingList(item.name, quantity: 1, dosage: item.dosage);
                ToastHelper.show(
                  context,
                  message: isInShoppingList
                      ? 'Количество «${item.name}» в покупках увеличено!'
                      : '«${item.name}» добавлен в список покупок!',
                  icon: '🛒',
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isInShoppingList
                      ? AppColors.primarySurface
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isInShoppingList
                        ? AppColors.primary
                        : AppColors.borderDarker,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isInShoppingList ? '✓' : '+',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isInShoppingList
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isInShoppingList ? 'В списке' : 'В список',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isInShoppingList
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SHOPPING LIST VIEW (WITH CROSS-LINKED PURCHASE LOGIC)
  // -------------------------------------------------------------
  Widget _buildShoppingListView(BuildContext context, AppState state) {
    final items = state.shoppingItems;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Text('🛒', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Список покупок в аптеку',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textMuted),
                  tooltip: 'Скопировать список',
                  onPressed: () {
                    final text = items
                        .map((item) =>
                            '• ${item.name}${item.count > 1 ? ' (${item.count} уп.)' : ''}')
                        .join('\n');
                    Clipboard.setData(ClipboardData(
                      text: 'Список покупок в аптеку:\n$text',
                    ));
                    ToastHelper.show(
                      context,
                      message: 'Список скопирован в буфер обмена!',
                      icon: '📋',
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Отметка «Куплено» сразу добавляет препарат в инвентарь аптечки и перекрашивает статус в рецептах в зеленый.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Action button to open full ShoppingListScreen
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBorderLight),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist_rounded, size: 16, color: AppColors.primaryHover),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Открыть полный список покупок',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryHover,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.primaryHover),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Add item input with quick quantity
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _newShoppingItemController,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Добавить препарат в список...',
                      hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (val) {
                      _addCustomShoppingItem(context, state);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _addCustomShoppingItem(context, state),
                child: const Text('+', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (items.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Text('🎉', style: TextStyle(fontSize: 32)),
                  SizedBox(height: 8),
                  Text(
                    'Список покупок пуст',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Все назначенные врачами препараты есть в вашей домашней аптечке.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (ctx, i) {
                final item = items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.statusExpiringBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.statusExpiringBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${item.count} уп.',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.statusExpiringText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (item.dosage.isNotEmpty)
                              Text(
                                item.dosage,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Reactive action: "Куплено" (real inventory addition)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.statusOkBg,
                          foregroundColor: AppColors.statusOkText,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          side: const BorderSide(color: Color(0xFFA7F3D0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          // Cross-linked logic: Adds to medicine inventory and updates recipe badges!
                          await state.purchaseShoppingItem(item.name, count: item.count);
                          if (ctx.mounted) {
                            ToastHelper.show(
                              ctx,
                              message: '«${item.name}» куплен и зачислен в аптечку! Статус в рецепте обновлен.',
                              icon: '🟢',
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 14),
                        label: const Text(
                          'Куплено',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        tooltip: 'Удалить из списка',
                        onPressed: () {
                          state.removeFromShoppingList(item.name);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _addCustomShoppingItem(BuildContext context, AppState state) {
    final text = _newShoppingItemController.text.trim();
    if (text.isEmpty) return;

    state.addToShoppingList(text);
    _newShoppingItemController.clear();
    ToastHelper.show(
      context,
      message: '«$text» добавлен в список покупок',
      icon: '🛒',
    );
  }
}
