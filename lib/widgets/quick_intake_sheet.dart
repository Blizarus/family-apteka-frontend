import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/medicine.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/parse_helper.dart';

class QuickIntakeSheet extends StatefulWidget {
  final Medicine medicine;
  final int? initialProfileId;

  const QuickIntakeSheet({
    super.key,
    required this.medicine,
    this.initialProfileId,
  });

  static Future<void> show(
    BuildContext context, {
    required Medicine medicine,
    int? initialProfileId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickIntakeSheet(
        medicine: medicine,
        initialProfileId: initialProfileId,
      ),
    );
  }

  @override
  State<QuickIntakeSheet> createState() => _QuickIntakeSheetState();
}

class _QuickIntakeSheetState extends State<QuickIntakeSheet> {
  int? _selectedProfileId;
  double _quantity = 1.0;
  String _selectedSymptom = '⚡ Боль в животе';
  final TextEditingController _customReasonController = TextEditingController();
  bool _isSubmitting = false;

  static const List<String> _predefinedSymptoms = [
    '⚡ Боль в животе',
    '🤕 Головная боль',
    '🌡️ Температура',
    '🤧 Аллергия',
    '🤢 Тошнота',
    '✏️ Своя причина',
  ];

  @override
  void initState() {
    super.initState();
    _selectedProfileId = widget.initialProfileId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    _selectedProfileId ??= state.selectedProfileId ?? state.profiles.firstOrNull?.id ?? 1;
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  String _formatQuantity(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toString();
  }

  String get _unitLabel {
    final formLower = widget.medicine.form.toLowerCase();
    if (formLower.contains('спрей')) return 'впрыск.';
    if (formLower.contains('капсул')) return 'капс.';
    if (formLower.contains('капл')) return 'кап.';
    if (formLower.contains('мл') || formLower.contains('сироп')) return 'мл';
    return 'табл.';
  }

  Future<void> _submitQuickIntake() async {
    if (_isSubmitting || _selectedProfileId == null) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    final state = context.read<AppState>();
    final isCustom = _selectedSymptom == '✏️ Своя причина';
    final customText = _customReasonController.text.trim();
    final symptom = isCustom
        ? (customText.isNotEmpty ? customText : 'По требованию')
        : _selectedSymptom;

    try {
      final res = await state.recordQuickIntake(
        medicineId: widget.medicine.id,
        profileId: _selectedProfileId!,
        quantity: _quantity,
        symptom: symptom,
      );

      final newRemaining = res['remaining'] != null
          ? ParseHelper.formatAny(res['remaining'])
          : ParseHelper.formatQuantity((widget.medicine.remaining - _quantity).clamp(0.0, 99999.0));

      if (mounted) {
        Navigator.of(context).pop();

        final formattedQty = _formatQuantity(_quantity);
        final snackMessage =
            '✓ Принято: ${widget.medicine.name} ($formattedQty $_unitLabel) • Остаток: $newRemaining';

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF0F172A),
            elevation: 6,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    snackMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF991B1B),
            content: Text('Ошибка записи приёма: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isStockExceeded = _quantity > widget.medicine.remaining;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + keyboardPadding),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Drag Handle
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

            // 2. Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primaryBorderLight),
                            ),
                            child: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Разовый приём',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '💊 ${widget.medicine.name} • Остаток: ${widget.medicine.remainingDisplay} $_unitLabel',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryHover,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textMuted,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Section: "Кто выпил?"
            const Text(
              'КТО ВЫПИЛ:',
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
                        HapticFeedback.selectionClick();
                        setState(() => _selectedProfileId = p.id);
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
            const SizedBox(height: 18),

            // 4. Section: "Сколько?" (Stepper + Quick Chips)
            const Text(
              'СКОЛЬКО:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatQuantity(_quantity)} $_unitLabel',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 26),
                        color: _quantity > 0.5 ? AppColors.primary : AppColors.textMuted,
                        onPressed: _quantity > 0.5
                            ? () {
                                HapticFeedback.selectionClick();
                                setState(() => _quantity -= 0.5);
                              }
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          _formatQuantity(_quantity),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 26),
                        color: _quantity < 10.0 ? AppColors.primary : AppColors.textMuted,
                        onPressed: _quantity < 10.0
                            ? () {
                                HapticFeedback.selectionClick();
                                setState(() => _quantity += 0.5);
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Quick quantity chips
            Row(
              children: [0.5, 1.0, 1.5, 2.0].map((val) {
                final isChosen = _quantity == val;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text('${_formatQuantity(val)} $_unitLabel'),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isChosen ? AppColors.primaryDeep : AppColors.textSecondary,
                    ),
                    backgroundColor: isChosen ? AppColors.primaryBorderLight : Colors.white,
                    side: BorderSide(
                      color: isChosen ? AppColors.primary : AppColors.border,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _quantity = val);
                    },
                  ),
                );
              }).toList(),
            ),

            // Stock deficit warning
            if (isStockExceeded) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.statusExpiringBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.statusExpiringBorder),
                ),
                child: Row(
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Внимание: доза (${_formatQuantity(_quantity)} $_unitLabel) превышает остаток в аптечке (${widget.medicine.remainingDisplay} $_unitLabel)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.statusExpiringText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),

            // 5. Section: "Причина / Симптом"
            const Text(
              'ПРИЧИНА / СИМПТОМ:',
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
              children: _predefinedSymptoms.map((sym) {
                final isSelected = _selectedSymptom == sym;
                return ChoiceChip(
                  label: Text(sym),
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
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedSymptom = sym);
                  },
                );
              }).toList(),
            ),

            // Custom symptom text input
            if (_selectedSymptom == '✏️ Своя причина') ...[
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _customReasonController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Укажите причину (например: зубная боль)...',
                    hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    prefixIcon: Icon(Icons.edit_note_rounded, size: 20, color: AppColors.primary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // 6. Action Button: "⚡ Подтвердить приём"
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSubmitting ? null : _submitQuickIntake,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.bolt_rounded, size: 20),
                label: Text(
                  _isSubmitting ? 'Запись приёма...' : '⚡ Подтвердить приём',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
