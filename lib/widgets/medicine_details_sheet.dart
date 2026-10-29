import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medicine.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'intake_course_wizard.dart';
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
                              '${m.remaining} из ${m.total} шт.',
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
}
