import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '⚠️ Препарат закончился в аптечке',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
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
            Text(
              'В аптечке недостаточно таблеток для списания остатка. Вы приняли лекарство (поделились / из другой упаковки)?',
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color ?? colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            if (medicineName.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.medication_rounded, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        medicineName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
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
              child: Text(
                'Отмена',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color ?? colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                side: BorderSide(color: colorScheme.primary),
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
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
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
