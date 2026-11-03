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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

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
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
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
                                  ? semantic.dangerBg
                                  : cs.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              m.isPrescription ? 'По рецепту' : 'Без рецепта',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: m.isPrescription
                                    ? semantic.dangerText
                                    : cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      if (m.substance.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'МНН: ${m.substance}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: textMuted),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: cs.outlineVariant),

          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              children: [
                // 1. Stock & Expiration Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ТЕКУЩИЙ ОСТАТОК',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${m.remainingDisplay} из ${m.totalDisplay} шт.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: cs.outlineVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'СРОК ГОДНОСТИ',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.expiry,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: m.isOk ? cs.onSurface : semantic.dangerText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildShelfLifeBlock(context, m, cs, semantic),
                _buildLowStockBlock(context, m, cs, semantic),
                const SizedBox(height: 12),

                // Main Actions: Quick Intake ("Выпить сейчас") & Assign Course ("Назначить курс")
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: cs.primaryContainer,
                          foregroundColor: cs.primary,
                          side: BorderSide(color: cs.outlineVariant, width: 1.2),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          QuickIntakeSheet.show(context, medicine: m);
                        },
                        icon: Icon(Icons.bolt_rounded, color: cs.primary, size: 20),
                        label: Text(
                          'Выпить сейчас',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
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
                      backgroundColor: cs.surface,
                      foregroundColor: cs.onSurface,
                      side: BorderSide(color: cs.outlineVariant),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      MoveMedicineSheet.show(context, medicine: m);
                    },
                    icon: Icon(Icons.drive_file_move_outlined, color: cs.onSurface, size: 20),
                    label: Text(
                      'Переместить в другую аптечку',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Clinical Safety Alert Banner (CDS) & Check Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'БЕЗОПАСНОСТЬ (CDS)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: textMuted,
                      ),
                    ),
                    Text(
                      'Пациент: $activePatient',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
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
                          backgroundColor: cs.primaryContainer,
                          foregroundColor: cs.primary,
                          side: BorderSide(color: cs.outlineVariant),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isLoadingSafety ? null : _checkSafety,
                        icon: _isLoadingSafety
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
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
                  Text(
                    'ПОТЕНЦИАЛЬНЫЕ АЛЛЕРГЕНЫ И ЭКСЦИПИЕНТЫ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: textMuted,
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
                          color: semantic.warningBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: semantic.warningBorder),
                        ),
                        child: Text(
                          '⚠️ $tag',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: semantic.warningText,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // 4. Pharmacy Metadata
                _buildMetadataSection(m, cs, textMuted),
                const SizedBox(height: 14),

                // 5. Expandable Instructions Accordion
                _buildInstructionsAccordion(m, cs, textSecondary, textMuted),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection(Medicine m, ColorScheme cs, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          if (m.manufacturer.isNotEmpty)
            _buildMetaRow('Производитель', '${m.manufacturer}${m.country.isNotEmpty ? ' (${m.country})' : ''}', cs, textMuted),
          if (m.atcCode.isNotEmpty)
            _buildMetaRow('АТХ-код', m.atcCode, cs, textMuted),
          if (m.barcode.isNotEmpty)
            _buildMetaRow('Штрихкод', m.barcode, cs, textMuted),
          if (m.composition.isNotEmpty)
            _buildMetaRow('Состав', m.composition, cs, textMuted),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, ColorScheme cs, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsAccordion(Medicine m, ColorScheme cs, Color textSecondary, Color textMuted) {
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
        Text(
          'ОФИЦИАЛЬНАЯ ИНСТРУКЦИЯ',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 6),
        ...sections.map((section) {
          final text = instructions[section['key']]?.toString();
          if (text == null || text.trim().isEmpty) return const SizedBox.shrink();

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  leading: Text(section['icon']!, style: const TextStyle(fontSize: 16)),
                  title: Text(
                    section['title']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
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

  Widget _buildLowStockBlock(BuildContext context, Medicine m, ColorScheme cs, SemanticColors semantic) {
    if (!m.isLowStock) return const SizedBox.shrink();

    final unit = _getUnitDisplay(m);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: semantic.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: semantic.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: semantic.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚠️ Заканчивается: осталось ${m.remainingDisplay} $unit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: semantic.warningText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Рекомендуется пополнить запас в аптечке',
                  style: TextStyle(
                    fontSize: 11,
                    color: semantic.warningText,
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: semantic.warning,
                  foregroundColor: cs.onPrimary,
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

  Widget _buildShelfLifeBlock(BuildContext context, Medicine m, ColorScheme cs, SemanticColors semantic) {
    if (m.openedAt == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.primary,
            side: BorderSide(color: cs.outlineVariant, width: 1.2),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
          ),
          onPressed: () => _showOpenBottleDialog(m, cs, semantic),
          icon: Icon(Icons.lock_open_rounded, size: 18, color: cs.primary),
          label: Text(
            'Вскрыть упаковку',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.primary,
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
        color: isExpired ? semantic.dangerBg : semantic.successBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired ? semantic.dangerBorder : semantic.successBorder,
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
                color: isExpired ? semantic.danger : semantic.success,
              ),
              const SizedBox(width: 6),
              Text(
                isExpired ? 'СРОК ПОСЛЕ ВСКРЫТИЯ ИСТЁК' : 'СРОК ГОДНОСТИ ПОСЛЕ ВСКРЫТИЯ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: isExpired ? semantic.dangerText : semantic.successText,
                ),
              ),
              if (isExpired) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: semantic.danger,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ИСТЁК',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: cs.onError,
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
              color: isExpired ? semantic.dangerText : semantic.successText,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showOpenBottleDialog(Medicine medicine, ColorScheme cs, SemanticColors semantic) async {
    final days = await showDialog<int>(
      context: context,
      builder: (_) => _OpenBottleDialog(medicine: medicine),
    );

    if (days != null && mounted) {
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

class _OpenBottleDialog extends StatefulWidget {
  final Medicine medicine;

  const _OpenBottleDialog({required this.medicine});

  @override
  State<_OpenBottleDialog> createState() => _OpenBottleDialogState();
}

class _OpenBottleDialogState extends State<_OpenBottleDialog> {
  late final TextEditingController _daysController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _daysController = TextEditingController(text: '30');
  }

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);

    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.inventory_2_outlined, color: cs.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            'Вскрыть упаковку',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Препарат: ${widget.medicine.name}',
              style: TextStyle(fontSize: 13, color: cs.onSurface, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Сколько дней годен после вскрытия?',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _daysController,
              keyboardType: TextInputType.number,
              autofocus: false,
              style: TextStyle(color: cs.onSurface, fontSize: 13),
              decoration: InputDecoration(
                suffixText: 'дн.',
                hintText: '30',
                hintStyle: TextStyle(color: textMuted),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
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
          onPressed: () => Navigator.of(context).pop(null),
          child: Text('Отмена', style: TextStyle(color: textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final days = int.tryParse(_daysController.text.trim()) ?? 30;
              Navigator.of(context).pop(days);
            }
          },
          child: const Text('Вскрыть'),
        ),
      ],
    );
  }
}
