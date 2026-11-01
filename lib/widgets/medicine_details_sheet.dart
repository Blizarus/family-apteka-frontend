import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medicine.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'intake_course_wizard.dart';
import 'move_medicine_sheet.dart';
import 'quick_intake_sheet.dart';
import 'safety_alert_banner.dart';
import 'toast_helper.dart';
import 'traffic_light_badge.dart';

class MedicineDetailsSheet extends StatefulWidget {
  final Medicine medicine;

  const MedicineDetailsSheet({
    super.key,
    required this.medicine,
  });

  static Future<void> show(BuildContext context, {required Medicine medicine}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicineDetailsSheet(medicine: medicine),
    );
  }

  @override
  State<MedicineDetailsSheet> createState() => _MedicineDetailsSheetState();
}

class _MedicineDetailsSheetState extends State<MedicineDetailsSheet> {
  Map<String, dynamic>? _safetyReport;
  bool _isLoadingSafety = false;
  bool _hasCheckedSafety = false;

  @override
  void initState() {
    super.initState();
    _checkSafety();
  }

  Future<void> _checkSafety() async {
    final state = context.read<AppState>();
    final profileId = state.selectedProfileId ?? state.profiles.firstOrNull?.id ?? 1;

    setState(() => _isLoadingSafety = true);
    try {
      final report = await state.checkSafety(
        profileId: profileId,
        medicineId: widget.medicine.id > 0 ? widget.medicine.id : null,
        referenceMedicineId: widget.medicine.referenceMedicineId,
      );
      if (mounted) {
        setState(() {
          _safetyReport = report;
          _isLoadingSafety = false;
          _hasCheckedSafety = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingSafety = false;
          _hasCheckedSafety = true;
        });
        ToastHelper.show(
          context,
          message: 'Не удалось проверить клиническую безопасность',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final m = state.medicines.cast<Medicine?>().firstWhere(
          (med) => med?.id == widget.medicine.id,
          orElse: () => widget.medicine,
        ) ??
        widget.medicine;
    final activePatient = state.selectedProfile?.name ?? 'Анна';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header with close button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TrafficLightBadge(status: m.status),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: m.isPrescription
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              m.isPrescription ? 'По рецепту' : 'Без рецепта',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: m.isPrescription
                                    ? const Color(0xFFB91C1C)
                                    : const Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (m.substance.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'МНН: ${m.substance}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryHover,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              children: [
                // 1. Stock & Expiration Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ТЕКУЩИЙ ОСТАТОК',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${m.remainingDisplay} из ${m.totalDisplay} шт.',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'СРОК ГОДНОСТИ',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.expiry,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: m.isOk ? AppColors.textPrimary : AppColors.statusExpiredText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildShelfLifeBlock(context, m),
                _buildLowStockBlock(context, m),
                const SizedBox(height: 12),

                // Main Actions: Quick Intake ("Выпить сейчас") & Assign Course ("Назначить курс")
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.primarySurface,
                          foregroundColor: const Color(0xFF0D9488),
                          side: const BorderSide(color: AppColors.primaryBorder, width: 1.2),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          QuickIntakeSheet.show(context, medicine: m);
                        },
                        icon: const Icon(Icons.bolt_rounded, color: Color(0xFF0D9488), size: 20),
                        label: const Text(
                          'Выпить сейчас',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          IntakeCourseWizard.show(context, initialMedicine: m);
                        },
                        icon: const Icon(Icons.add_task_rounded, size: 18),
                        label: const Text(
                          'Назначить курс',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Move medicine to another box action
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      MoveMedicineSheet.show(context, medicine: m);
                    },
                    icon: const Icon(Icons.drive_file_move_outlined, color: AppColors.textPrimary, size: 20),
                    label: const Text(
                      'Переместить в другую аптечку',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Clinical Safety Alert Banner (CDS) & Check Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'БЕЗОПАСНОСТЬ (CDS)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      'Пациент: $activePatient',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryHover,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Check button
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.primarySurface,
                          foregroundColor: AppColors.primaryHover,
                          side: const BorderSide(color: AppColors.primaryBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isLoadingSafety ? null : _checkSafety,
                        icon: _isLoadingSafety
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Icon(Icons.shield_outlined, size: 16),
                        label: const Text(
                          'Проверить совместимость',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_hasCheckedSafety || _isLoadingSafety) ...[
                  SafetyAlertBanner(
                    safetyData: _safetyReport,
                    isLoading: _isLoadingSafety,
                  ),
                  const SizedBox(height: 14),
                ],

                // 3. Allergens Chips (if any)
                if (m.allergenTags.isNotEmpty) ...[
                  const Text(
                    'ПОТЕНЦИАЛЬНЫЕ АЛЛЕРГЕНЫ И ЭКСЦИПИЕНТЫ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: m.allergenTags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          '⚠️ $tag',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // 4. Pharmacy Metadata
                _buildMetadataSection(m),
                const SizedBox(height: 14),

                // 5. Expandable Instructions Accordion
                _buildInstructionsAccordion(m),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection(Medicine m) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (m.manufacturer.isNotEmpty)
            _buildMetaRow('Производитель', '${m.manufacturer}${m.country.isNotEmpty ? ' (${m.country})' : ''}'),
          if (m.atcCode.isNotEmpty)
            _buildMetaRow('АТХ-код', m.atcCode),
          if (m.barcode.isNotEmpty)
            _buildMetaRow('Штрихкод', m.barcode),
          if (m.composition.isNotEmpty)
            _buildMetaRow('Состав', m.composition),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsAccordion(Medicine m) {
    final instructions = m.instructions;
    if (instructions.isEmpty) {
      return const SizedBox.shrink();
    }

    final sections = [
      {'key': 'indications', 'title': 'Показания к применению', 'icon': '📋'},
      {'key': 'contraindications', 'title': 'Противопоказания', 'icon': '⛔'},
      {'key': 'dosage', 'title': 'Способ применения и дозы', 'icon': '🥄'},
      {'key': 'side_effects', 'title': 'Побочные действия', 'icon': '⚠️'},
      {'key': 'storage', 'title': 'Условия хранения', 'icon': '🌡️'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ОФИЦИАЛЬНАЯ ИНСТРУКЦИЯ',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        ...sections.map((section) {
          final text = instructions[section['key']]?.toString();
          if (text == null || text.trim().isEmpty) return const SizedBox.shrink();

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  leading: Text(section['icon']!, style: const TextStyle(fontSize: 16)),
                  title: Text(
                    section['title']!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d.$m.$y';
  }

  String _getUnitDisplay(Medicine m) {
    if (m.quantityUnit.isNotEmpty && m.quantityUnit != 'pill') {
      return m.quantityUnit;
    }
    final formLower = m.form.toLowerCase();
    if (formLower.contains('спрей')) return 'впрыск.';
    if (formLower.contains('капсул')) return 'капс.';
    if (formLower.contains('капл')) return 'кап.';
    if (formLower.contains('мл') || formLower.contains('сироп')) return 'мл';
    return 'табл.';
  }

  Widget _buildLowStockBlock(BuildContext context, Medicine m) {
    if (!m.isLowStock) return const SizedBox.shrink();

    final unit = _getUnitDisplay(m);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFD97706),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚠️ Заканчивается: осталось ${m.remainingDisplay} $unit',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Рекомендуется пополнить запас в аптечке',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final state = context.read<AppState>();
                  state.addToShoppingList(
                    m.name,
                    quantity: (m.total > 0 ? m.total : 1).round(),
                    dosage: m.form,
                  );
                  ToastHelper.show(
                    context,
                    message: '${m.name} добавлен в список покупок',
                  );
                },
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                label: const Text(
                  '+ В список покупок',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShelfLifeBlock(BuildContext context, Medicine m) {
    if (m.openedAt == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFF0FDFA),
            foregroundColor: const Color(0xFF0D9488),
            side: const BorderSide(color: Color(0xFF99F6E4), width: 1.2),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
          ),
          onPressed: () => _showOpenBottleDialog(m),
          icon: const Icon(Icons.lock_open_rounded, size: 18, color: Color(0xFF0D9488)),
          label: const Text(
            'Вскрыть упаковку',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D9488),
            ),
          ),
        ),
      );
    }

    final openedDateStr = _formatDate(m.openedAt!);
    final expDate = m.effectiveExpirationDate ??
        m.openedAt!.add(Duration(days: m.daysAfterOpening ?? 30));
    final expDateStr = _formatDate(expDate);
    final daysLeft = expDate.difference(DateTime.now()).inDays;
    final isExpired = daysLeft < 0;

    final infoText =
        'Вскрыто: $openedDateStr • Годен до $expDateStr (осталось $daysLeft дн.)';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isExpired ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isExpired ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                size: 16,
                color: isExpired ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              ),
              const SizedBox(width: 6),
              Text(
                isExpired ? 'СРОК ПОСЛЕ ВСКРЫТИЯ ИСТЁК' : 'СРОК ГОДНОСТИ ПОСЛЕ ВСКРЫТИЯ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: isExpired ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                ),
              ),
              if (isExpired) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ИСТЁК',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            infoText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isExpired ? const Color(0xFF991B1B) : const Color(0xFF166534),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showOpenBottleDialog(Medicine medicine) async {
    final controller = TextEditingController(text: '30');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.inventory_2_outlined, color: Color(0xFF0D9488), size: 22),
              SizedBox(width: 8),
              Text(
                'Вскрыть упаковку',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Препарат: ${medicine.name}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Сколько дней годен после вскрытия?',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: false,
                  decoration: InputDecoration(
                    suffixText: 'дн.',
                    hintText: '30',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (val) {
                    final numVal = int.tryParse(val?.trim() ?? '');
                    if (numVal == null || numVal <= 0) {
                      return 'Введите положительное число дней';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Отмена', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogCtx).pop(true);
                }
              },
              child: const Text('Вскрыть'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final days = int.tryParse(controller.text.trim()) ?? 30;
      try {
        await context.read<AppState>().openMedicine(medicine.id, daysAfterOpening: days);
        if (mounted) {
          ToastHelper.show(context, message: 'Упаковка успешно вскрыта');
        }
      } catch (e) {
        if (mounted) {
          ToastHelper.show(context, message: 'Ошибка при вскрытии: $e', isError: true);
        }
      }
    }
  }
}
