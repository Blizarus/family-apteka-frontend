import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medicine.dart';
import '../models/reference_medicine.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'safety_alert_banner.dart';
import 'toast_helper.dart';

class IntakeCourseWizard extends StatefulWidget {
  final Medicine? initialMedicine;
  final String? initialMedicineName;
  final int? initialProfileId;

  const IntakeCourseWizard({
    super.key,
    this.initialMedicine,
    this.initialMedicineName,
    this.initialProfileId,
  });

  static Future<void> show(
    BuildContext context, {
    Medicine? initialMedicine,
    String? initialMedicineName,
    int? initialProfileId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IntakeCourseWizard(
        initialMedicine: initialMedicine,
        initialMedicineName: initialMedicineName,
        initialProfileId: initialProfileId,
      ),
    );
  }

  @override
  State<IntakeCourseWizard> createState() => _IntakeCourseWizardState();
}

class _IntakeCourseWizardState extends State<IntakeCourseWizard> {
  int _currentStep = 1; // 1 to 5

  // Step 1: Medicine
  Medicine? _selectedMedicine;
  final TextEditingController _searchController = TextEditingController();
  List<ReferenceMedicine> _catalogSuggestions = [];
  bool _isSearchingCatalog = false;
  Timer? _searchDebounce;
  Map<String, dynamic>? _safetyReport;
  bool _isCheckingSafety = false;

  // Step 2: Patient & Dose
  int? _selectedProfileId;
  double _dosageQuantity = 1.0;
  bool _isAddedToShoppingList = false;

  // Step 3: Frequency & Food Relation
  String _selectedFrequency = '2 раза в день'; // '1 раз в день', '2 раза в день', '3 раза в день', 'По симптомам'
  String _selectedFoodRelation = 'Во время еды'; // 'До еды', 'Во время еды', 'После еды', 'Не зависит от еды'

  // Step 4: Time Slots & Reminders
  List<String> _timeSlots = ['08:00', '20:00'];
  bool _remind15MinBefore = true;

  // Step 5: Duration
  int _durationDays = 7; // 5, 7, 10, 14, 0 (0 = indefinite)
  final DateTime _startDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedMedicine = widget.initialMedicine;
    _selectedProfileId = widget.initialProfileId;

    if (_selectedMedicine != null) {
      _checkSafety();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    _selectedProfileId ??= state.selectedProfileId ?? state.profiles.firstOrNull?.id ?? 1;

    // If initial medicine name is given but not initialMedicine, find match in inventory
    if (_selectedMedicine == null && widget.initialMedicineName != null) {
      final nameLower = widget.initialMedicineName!.toLowerCase().trim();
      final match = state.medicines.cast<Medicine?>().firstWhere(
            (m) =>
                m != null &&
                (m.name.toLowerCase().contains(nameLower) ||
                    nameLower.contains(m.name.toLowerCase())),
            orElse: () => null,
          );
      if (match != null) {
        _selectedMedicine = match;
        _checkSafety();
      } else {
        _searchController.text = widget.initialMedicineName!;
        _performCatalogSearch(widget.initialMedicineName!);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _checkSafety() async {
    if (_selectedMedicine == null || _selectedProfileId == null) return;
    setState(() => _isCheckingSafety = true);
    try {
      final state = context.read<AppState>();
      final report = await state.checkSafety(
        profileId: _selectedProfileId!,
        medicineId: _selectedMedicine!.id > 0 ? _selectedMedicine!.id : null,
        referenceMedicineId: _selectedMedicine!.referenceMedicineId,
      );
      if (mounted) {
        setState(() {
          _safetyReport = report;
          _isCheckingSafety = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingSafety = false);
    }
  }

  void _performCatalogSearch(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _catalogSuggestions = []);
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _isSearchingCatalog = true);
      try {
        final state = context.read<AppState>();
        final results = await state.apiService.searchReferenceMedicines(query);
        if (mounted) {
          setState(() {
            _catalogSuggestions = results;
            _isSearchingCatalog = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearchingCatalog = false);
      }
    });
  }

  void _onFrequencyChanged(String freq) {
    setState(() {
      _selectedFrequency = freq;
      if (freq == '1 раз в день') {
        _timeSlots = ['08:00'];
      } else if (freq == '2 раза в день') {
        _timeSlots = ['08:00', '20:00'];
      } else if (freq == '3 раза в день') {
        _timeSlots = ['08:00', '13:00', '20:00'];
      } else {
        _timeSlots = ['09:00'];
      }
    });
  }

  Future<void> _pickTimeSlot(int index) async {
    final currentSlot = _timeSlots[index];
    final parts = currentSlot.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _timeSlots[index] = formatted;
        _timeSlots.sort();
      });
    }
  }

  void _addTimeSlot() {
    setState(() {
      _timeSlots.add('18:00');
      _timeSlots.sort();
    });
  }

  void _removeTimeSlot(int index) {
    if (_timeSlots.length <= 1) return;
    setState(() {
      _timeSlots.removeAt(index);
    });
  }

  int get _calculatedNeededQuantity {
    final dailyIntakes = _timeSlots.length;
    final days = _durationDays > 0 ? _durationDays : 30;
    return (dailyIntakes * days * _dosageQuantity).ceil();
  }

  Future<void> _submitCourse() async {
    if (_selectedMedicine == null || _selectedProfileId == null) return;

    setState(() => _isSubmitting = true);
    final state = context.read<AppState>();

    try {
      final startDateFormatted =
          "${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}";
      DateTime? endDate;
      if (_durationDays > 0) {
        endDate = _startDate.add(Duration(days: _durationDays - 1));
      }
      final endDateFormatted = endDate != null
          ? "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}"
          : null;

      final ruleText = '$_selectedFoodRelation • ${_formatDosage(_dosageQuantity)} ${_selectedMedicine!.form.toLowerCase()}';
      final title = 'Курс: ${_selectedMedicine!.name}';

      final payload = {
        'profile_id': _selectedProfileId,
        'medicine_id': _selectedMedicine!.id > 0 ? _selectedMedicine!.id : 1,
        'title': title,
        'start_date': startDateFormatted,
        'end_date': ?endDateFormatted,
        'time_slots': _timeSlots,
        'dosage_quantity': _dosageQuantity,
        'dosage_instruction': ruleText,
        'rule': ruleText,
        'notes': 'Напоминание за ${_remind15MinBefore ? 15 : 0} мин',
      };

      await state.createIntakeCourse(payload);

      if (mounted) {
        Navigator.of(context).pop();
        ToastHelper.showSuccess(
          context,
          'Курс приёма успешно создан! Расписание добавлено в календарь.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ToastHelper.showError(context, 'Не удалось создать курс: $e');
      }
    }
  }

  String _formatDosage(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toString();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 1. Drag Handle
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDarker,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Wizard Header with Steps
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Шаг $_currentStep из 5'.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.primaryHover,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getStepTitle(_currentStep),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.textMuted,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Step Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _currentStep / 5.0,
                    minHeight: 4,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Scrollable Step Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (_currentStep == 1) _buildStep1MedicineSelection(state),
                    if (_currentStep == 2) _buildStep2PatientAndDosage(state),
                    if (_currentStep == 3) _buildStep3FrequencyAndFood(state),
                    if (_currentStep == 4) _buildStep4TimeSlots(),
                    if (_currentStep == 5) _buildStep5Summary(state),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // 4. Wizard Bottom Controls
              _buildBottomActionBar(),
            ],
          ),
        );
      },
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 1:
        return 'Выбор препарата';
      case 2:
        return 'Пациент и разовая доза';
      case 3:
        return 'Частота и приём пищи';
      case 4:
        return 'Время приёма и уведомления';
      case 5:
        return 'Длительность и подтверждение';
      default:
        return 'Назначение курса';
    }
  }

  // -------------------------------------------------------------
  // STEP 1: Medicine Selection
  // -------------------------------------------------------------
  Widget _buildStep1MedicineSelection(AppState state) {
    final query = _searchController.text.trim().toLowerCase();
    final inStockMedicines = state.medicines.where((m) {
      if (query.isEmpty) return true;
      return m.name.toLowerCase().contains(query) ||
          m.substance.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {});
              _performCatalogSearch(val);
            },
            decoration: InputDecoration(
              hintText: 'Поиск по названию или веществу...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
              suffixIcon: _isSearchingCatalog
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // CDS Safety warning banner if active
        if (_selectedMedicine != null && _safetyReport != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SafetyAlertBanner(
              safetyData: _safetyReport,
              isLoading: _isCheckingSafety,
            ),
          ),

        // Selected preview
        if (_selectedMedicine != null) ...[
          const Text(
            'ВЫБРАННЫЙ ПРЕПАРАТ:',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          _buildMedicineCard(_selectedMedicine!, isSelected: true),
          const SizedBox(height: 14),
        ],

        // In Stock list
        const Text(
          'ИЗ ВАШЕЙ АПТЕЧКИ:',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),

        if (inStockMedicines.isEmpty && query.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'В аптечке пока нет лекарств.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          )
        else
          ...inStockMedicines.map(
            (med) => _buildMedicineCard(
              med,
              isSelected: _selectedMedicine?.id == med.id,
              onTap: () {
                setState(() => _selectedMedicine = med);
                _checkSafety();
              },
            ),
          ),

        // Catalog Reference suggestions
        if (_catalogSuggestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'ИЗ СПРАВОЧНИКА ЛЕКАРСТВ (ГРЛС):',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          ..._catalogSuggestions.map((ref) {
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                final tempMed = Medicine(
                  id: 0,
                  boxId: state.selectedBoxId,
                  name: ref.tradeName,
                  substance: ref.inn,
                  form: ref.dosageForm,
                  remaining: 0,
                  total: ref.packSize.toDouble(),
                  expiry: 'По назначению',
                  status: 'ok',
                  referenceMedicineId: ref.id,
                  manufacturer: ref.manufacturer,
                  country: ref.country,
                  instructions: ref.instructions,
                );
                setState(() => _selectedMedicine = tempMed);
                _checkSafety();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Text('💊', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref.tradeName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${ref.inn} • ${ref.dosageForm} (${ref.dosage})',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Выбрать',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildMedicineCard(
    Medicine med, {
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? AppColors.primarySurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    med.form.toLowerCase().contains('спрей') ? '💨' : '💊',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.primaryDeep : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${med.form} • В аптечке: ${med.remainingDisplay} шт.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? AppColors.primaryHover : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 2: Patient Selector & Single Dose
  // -------------------------------------------------------------
  Widget _buildStep2PatientAndDosage(AppState state) {
    final med = _selectedMedicine!;
    final isLowStock = med.remaining < 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Patient selector
        const Text(
          'КТО БУДЕТ ПРИНИМАТЬ:',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: state.profiles.map((p) {
              final isSelected = _selectedProfileId == p.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: () {
                    setState(() => _selectedProfileId = p.id);
                    _checkSafety();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                        Text(p.avatar, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // Dosage Stepper
        const Text(
          'РАЗОВАЯ ДОЗА:',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatDosage(_dosageQuantity)} ${med.form.toLowerCase()}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 24),
                    color: _dosageQuantity > 0.5 ? AppColors.primary : AppColors.textMuted,
                    onPressed: _dosageQuantity > 0.5
                        ? () => setState(() => _dosageQuantity -= 0.5)
                        : null,
                  ),
                  Text(
                    _formatDosage(_dosageQuantity),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
                    color: _dosageQuantity < 5.0 ? AppColors.primary : AppColors.textMuted,
                    onPressed: _dosageQuantity < 5.0
                        ? () => setState(() => _dosageQuantity += 0.5)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Quick Dosage Chips
        Row(
          children: [0.5, 1.0, 1.5, 2.0].map((val) {
            final isChosen = _dosageQuantity == val;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                label: Text('${_formatDosage(val)} шт.'),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isChosen ? AppColors.primaryDeep : AppColors.textSecondary,
                ),
                backgroundColor: isChosen ? AppColors.primaryBorderLight : Colors.white,
                side: BorderSide(
                  color: isChosen ? AppColors.primary : AppColors.border,
                ),
                onPressed: () => setState(() => _dosageQuantity = val),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // Inventory Stock Warning & Shopping List Bridge
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isLowStock ? AppColors.statusExpiringBg : AppColors.statusOkBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLowStock ? AppColors.statusExpiringBorder : const Color(0xFFA7F3D0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(isLowStock ? '⚠️' : '✓', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isLowStock
                          ? 'Остаток в аптечке мал (${med.remainingDisplay} шт.)'
                          : 'В аптечке достаточно запаса (${med.remainingDisplay} шт.)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isLowStock ? AppColors.statusExpiringText : AppColors.statusOkText,
                      ),
                    ),
                  ),
                ],
              ),
              if (isLowStock) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryHover,
                    elevation: 0,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isAddedToShoppingList
                      ? null
                      : () {
                          state.addToShoppingList(med.name, quantity: 1);
                          setState(() => _isAddedToShoppingList = true);
                          ToastHelper.showSuccess(context, 'Добавлено в список покупок');
                        },
                  icon: Icon(
                    _isAddedToShoppingList ? Icons.check : Icons.add_shopping_cart_rounded,
                    size: 16,
                  ),
                  label: Text(
                    _isAddedToShoppingList
                        ? '✓ Добавлено в список покупок'
                        : '+ Добавить в список покупок',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // STEP 3: Frequency & Food Relation
  // -------------------------------------------------------------
  Widget _buildStep3FrequencyAndFood(AppState state) {
    final med = _selectedMedicine!;
    final officialDosageHint = med.instructions['dosage']?.toString();

    final frequencies = [
      '1 раз в день',
      '2 раза в день',
      '3 раза в день',
      'По симптомам',
    ];

    final foodOptions = [
      'До еды',
      'Во время еды',
      'После еды',
      'Не зависит от еды',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Frequency chips
        const Text(
          'ЧАСТОТА ПРИЁМА:',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: frequencies.map((freq) {
            final isSelected = _selectedFrequency == freq;
            return ChoiceChip(
              label: Text(freq),
              selected: isSelected,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
              onSelected: (_) => _onFrequencyChanged(freq),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Food Relation chips
        const Text(
          'ОТНОШЕНИЕ К ПРИЁМУ ПИЩИ:',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: foodOptions.map((opt) {
            final isSelected = _selectedFoodRelation == opt;
            return ChoiceChip(
              label: Text(opt),
              selected: isSelected,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
              onSelected: (_) => setState(() => _selectedFoodRelation = opt),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Official Instruction hint
        if (officialDosageHint != null && officialDosageHint.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Рекомендация из инструкции:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF166534),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        officialDosageHint,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF15803D),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------
  // STEP 4: Time Slots & Notifications
  // -------------------------------------------------------------
  Widget _buildStep4TimeSlots() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ВРЕМЯ ПРИЁМА В ТЕЧЕНИЕ ДНЯ:',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),

        // Time slot pills
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _timeSlots.asMap().entries.map((entry) {
            final idx = entry.key;
            final slot = entry.value;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _pickTimeSlot(idx),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          slot,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_timeSlots.length > 1) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _removeTimeSlot(idx),
                      child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),

        // Button to add custom time slot
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _addTimeSlot,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Добавить время', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 20),

        // Reminder Switch
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🔔', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text(
                    'Напомнить за 15 минут',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _remind15MinBefore,
                activeTrackColor: AppColors.primaryLight,
                activeThumbColor: AppColors.primary,
                onChanged: (val) => setState(() => _remind15MinBefore = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // STEP 5: Duration & Summary
  // -------------------------------------------------------------
  Widget _buildStep5Summary(AppState state) {
    final med = _selectedMedicine!;
    final profile = state.profiles.firstWhere(
      (p) => p.id == _selectedProfileId,
      orElse: () => state.profiles.first,
    );

    final durationOptions = [
      {'label': '5 дней', 'days': 5},
      {'label': '7 дней', 'days': 7},
      {'label': '10 дней', 'days': 10},
      {'label': '14 дней', 'days': 14},
      {'label': 'Бессрочно', 'days': 0},
    ];

    final needed = _calculatedNeededQuantity;
    final isEnough = med.remaining >= needed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Duration chips
        const Text(
          'ДЛИТЕЛЬНОСТЬ КУРСА:',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: durationOptions.map((opt) {
            final days = opt['days'] as int;
            final isSelected = _durationDays == days;

            return ChoiceChip(
              label: Text(opt['label'] as String),
              selected: isSelected,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
              onSelected: (_) => setState(() => _durationDays = days),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Summary Card
        const Text(
          'ИТОГОВОЕ НАЗНАЧЕНИЕ:',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(profile.avatar, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Пациент: ${profile.name}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: AppColors.primaryBorder, height: 16),
              Text(
                '💊 Препарат: ${med.name}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '🥄 Доза: ${_formatDosage(_dosageQuantity)} ${med.form.toLowerCase()} • $_selectedFoodRelation',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '⏰ Время: ${_timeSlots.join(', ')} (${_remind15MinBefore ? "уведомление за 15 мин" : "без уведомления"})',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '📅 Срок: ${_durationDays > 0 ? "$_durationDays дней" : "Постоянный приём"}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isEnough ? AppColors.statusOkBg : AppColors.statusExpiringBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isEnough
                      ? '✓ Требуется ~$needed шт. В наличии: ${med.remainingDisplay} шт. (Запаса хватает)'
                      : '⚠️ Требуется ~$needed шт. В наличии: ${med.remainingDisplay} шт. (Потребуется докупить)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isEnough ? AppColors.statusOkText : AppColors.statusExpiringText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Bottom Action Bar
  // -------------------------------------------------------------
  Widget _buildBottomActionBar() {
    final canProceedStep1 = _selectedMedicine != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_currentStep > 1) ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () => setState(() => _currentStep--),
              child: const Text('Назад'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (_currentStep == 1 && !canProceedStep1) {
                        ToastHelper.showError(context, 'Выберите препарат для продолжения');
                        return;
                      }

                      if (_currentStep < 5) {
                        setState(() => _currentStep++);
                      } else {
                        _submitCourse();
                      }
                    },
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _currentStep == 5 ? 'Создать курс приёма' : 'Далее →',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
