import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum OutOfStockDialogResult {
  cancel,
  addToShopping,
  confirmIntake,
}

class OutOfStockConfirmationDialog extends StatelessWidget {
  final String medicineName;
  final double remainingQuantity;
  final VoidCallback? onCancel;
  final VoidCallback? onAddToShoppingList;
  final VoidCallback? onConfirmIntake;

  const OutOfStockConfirmationDialog({
    super.key,
    required this.medicineName,
    this.remainingQuantity = 0.0,
    this.onCancel,
    this.onAddToShoppingList,
    this.onConfirmIntake,
  });

  static Future<OutOfStockDialogResult?> show(
    BuildContext context, {
    required String medicineName,
    double remainingQuantity = 0.0,
    VoidCallback? onCancel,
    VoidCallback? onAddToShoppingList,
    VoidCallback? onConfirmIntake,
  }) {
    return showDialog<OutOfStockDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OutOfStockConfirmationDialog(
        medicineName: medicineName,
        remainingQuantity: remainingQuantity,
        onCancel: onCancel,
        onAddToShoppingList: onAddToShoppingList,
        onConfirmIntake: onConfirmIntake,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: const Row(
        children: [
          Expanded(
            child: Text(
              '⚠️ Препарат закончился в аптечке',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'В аптечке недостаточно таблеток для списания остатка. Вы приняли лекарство (поделились / из другой упаковки)?',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (medicineName.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.medication_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        medicineName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: () {
                onCancel?.call();
                Navigator.of(context).pop(OutOfStockDialogResult.cancel);
              },
              child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                onAddToShoppingList?.call();
                Navigator.of(context).pop(OutOfStockDialogResult.addToShopping);
              },
              child: const Text('+ В список покупок'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                onConfirmIntake?.call();
                Navigator.of(context).pop(OutOfStockDialogResult.confirmIntake);
              },
              child: const Text('Зафиксировать приём'),
            ),
          ],
        ),
      ],
    );
  }
}
