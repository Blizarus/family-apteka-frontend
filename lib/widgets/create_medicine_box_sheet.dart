import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/medicine_box.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'toast_helper.dart';

class BoxTypeOption {
  final String key;
  final String label;
  final String emoji;
  final String description;

  const BoxTypeOption({
    required this.key,
    required this.label,
    required this.emoji,
    required this.description,
  });
}

class CreateMedicineBoxSheet extends StatefulWidget {
  const CreateMedicineBoxSheet({super.key});

  static Future<MedicineBox?> show(BuildContext context) {
    return showModalBottomSheet<MedicineBox?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreateMedicineBoxSheet(),
    );
  }

  @override
  State<CreateMedicineBoxSheet> createState() => _CreateMedicineBoxSheetState();
}

class _CreateMedicineBoxSheetState extends State<CreateMedicineBoxSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String _selectedBoxType = 'home';
  bool _isSubmitting = false;
  String? _nameError;

  static const List<BoxTypeOption> _boxTypes = [
    BoxTypeOption(
      key: 'home',
      label: 'Домашняя',
      emoji: '🏠',
      description: 'Основная аптечка в доме',
    ),
    BoxTypeOption(
      key: 'car',
      label: 'Автомобильная',
      emoji: '🚗',
      description: 'В бардачок или багажник',
    ),
    BoxTypeOption(
      key: 'child',
      label: 'Детская',
      emoji: '👶',
      description: 'Специальные детские препараты',
    ),
    BoxTypeOption(
      key: 'travel',
      label: 'Дорожная / Походная',
      emoji: '✈️',
      description: 'В дорогу или походный рюкзак',
    ),
    BoxTypeOption(
      key: 'custom',
      label: 'Другое / Индивидуальная',
      emoji: '📦',
      description: 'Кастомный набор медикаментов',
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Введите название аптечки');
      ToastHelper.show(
        context,
        message: 'Пожалуйста, введите название аптечки',
        isError: true,
        icon: '⚠️',
      );
      return;
    }

    setState(() {
      _nameError = null;
      _isSubmitting = true;
    });

    HapticFeedback.mediumImpact();

    try {
      final state = context.read<AppState>();
      final location = _locationController.text.trim();

      final newBox = await state.createMedicineBox(
        name: name,
        boxType: _selectedBoxType,
        description: location.isNotEmpty ? location : null,
      );

      if (!mounted) return;

      if (newBox != null) {
        state.selectBox(newBox.id);
        Navigator.pop(context, newBox);
        ToastHelper.show(
          context,
          message: '✓ Аптечка «$name» успешно создана!',
          icon: '✓',
        );
      } else {
        setState(() => _isSubmitting = false);
        ToastHelper.show(
          context,
          message: 'Не удалось создать аптечку',
          isError: true,
          icon: '✕',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ToastHelper.show(
          context,
          message: 'Ошибка при создании аптечки: $e',
          isError: true,
          icon: '✕',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + keyboardPadding),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header: Title & Subtitle
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    MedicineBox.getIconForBoxType(_selectedBoxType),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Новая аптечка',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Создайте категорию для раздельного хранения медикаментов',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // Section 1: Box Name
            const Text(
              'НАЗВАНИЕ АПТЕЧКИ *',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _nameError != null ? AppColors.danger : AppColors.border,
                  width: _nameError != null ? 1.5 : 1.0,
                ),
              ),
              child: TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: AppColors.primaryHover,
                  ),
                  hintText: 'Например, Дачная аптечка, Походный рюкзак...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                ),
                onChanged: (val) {
                  if (_nameError != null && val.trim().isNotEmpty) {
                    setState(() => _nameError = null);
                  }
                },
              ),
            ),
            if (_nameError != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  _nameError!,
                  style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Section 2: Box Type Grid
            const Text(
              'ТИП ХРАНИЛИЩА',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _boxTypes.map((type) {
                final isSelected = _selectedBoxType == type.key;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selectedBoxType = type.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primarySurface : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(type.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          type.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? AppColors.primaryDeep : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Section 3: Location / Description
            const Text(
              'ГДЕ НАХОДИТСЯ (ЛОКАЦИЯ)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _locationController,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: AppColors.primaryHover,
                  ),
                  hintText: 'Например, Шкаф в коридоре, полка 2, Бардачок...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Section 4: Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSubmitting ? null : _handleCreate,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(
                  _isSubmitting ? 'Создание...' : '✓ Создать аптечку',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
