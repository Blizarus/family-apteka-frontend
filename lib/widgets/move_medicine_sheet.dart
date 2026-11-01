import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medicine.dart';
import '../models/medicine_box.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'toast_helper.dart';

class MoveMedicineSheet extends StatefulWidget {
  final Medicine medicine;

  const MoveMedicineSheet({
    super.key,
    required this.medicine,
  });

  static Future<bool?> show(BuildContext context, {required Medicine medicine}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MoveMedicineSheet(medicine: medicine),
    );
  }

  @override
  State<MoveMedicineSheet> createState() => _MoveMedicineSheetState();
}

class _MoveMedicineSheetState extends State<MoveMedicineSheet> {
  int? _selectedTargetBoxId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final available = state.boxes.where((b) => b.id != widget.medicine.boxId).toList();
    if (available.isNotEmpty) {
      _selectedTargetBoxId = available.first.id;
    }
  }

  String _formatBoxType(String boxType) {
    switch (boxType.toLowerCase()) {
      case 'home':
        return 'Домашняя';
      case 'car':
        return 'Автомобильная';
      case 'child':
        return 'Детская';
      case 'travel':
        return 'Дорожная';
      default:
        return 'Хранилище';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currentBox = state.boxes.cast<MedicineBox?>().firstWhere(
          (b) => b?.id == widget.medicine.boxId,
          orElse: () => null,
        );
    final availableBoxes = state.boxes.where((b) => b.id != widget.medicine.boxId).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.drive_file_move_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Перемещение препарата',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Препарат: ${widget.medicine.name}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Current Box indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                const Text(
                  'ТЕКУЩЕЕ ХРАНИЛИЩЕ: ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  currentBox != null ? '${currentBox.icon} ${currentBox.name}' : 'Аптечка #${widget.medicine.boxId}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Title for target boxes
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Text(
              'ВЫБЕРИТЕ ЦЕЛЕВУЮ АПТЕЧКУ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
          ),

          // Boxes List
          Flexible(
            child: availableBoxes.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: const Text(
                      'Нет других доступных аптечек для перемещения',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    itemCount: availableBoxes.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final box = availableBoxes[index];
                      final isSelected = box.id == _selectedTargetBoxId;

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() => _selectedTargetBoxId = box.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primarySurface : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryBorder : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(box.icon, style: const TextStyle(fontSize: 20)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            box.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceSubtle,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _formatBoxType(box.boxType),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (box.location.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        box.location,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected ? AppColors.primary : AppColors.textMuted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Submit Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: (_selectedTargetBoxId == null || _isSubmitting)
                  ? null
                  : () async {
                      setState(() => _isSubmitting = true);
                      final targetBox = state.boxes.cast<MedicineBox?>().firstWhere(
                            (b) => b?.id == _selectedTargetBoxId,
                            orElse: () => null,
                          );
                      final success = await state.moveMedicine(
                        widget.medicine.id,
                        _selectedTargetBoxId!,
                      );
                      if (!context.mounted) return;
                      setState(() => _isSubmitting = false);
                      if (success) {
                        Navigator.of(context).pop(true);
                        ToastHelper.show(
                          context,
                          message: 'Препарат «${widget.medicine.name}» перемещён в ${targetBox?.name ?? 'новую аптечку'}',
                        );
                      } else {
                        ToastHelper.show(
                          context,
                          message: 'Не удалось переместить препарат',
                          isError: true,
                        );
                      }
                    },
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Переместить препарат',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
