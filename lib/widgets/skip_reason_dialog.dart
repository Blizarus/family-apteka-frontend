import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SkipReasonDialog extends StatefulWidget {
  final String medicineName;

  const SkipReasonDialog({
    super.key,
    required this.medicineName,
  });

  static Future<String?> show(BuildContext context, {required String medicineName}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SkipReasonDialog(medicineName: medicineName),
    );
  }

  @override
  State<SkipReasonDialog> createState() => _SkipReasonDialogState();
}

class _SkipReasonDialogState extends State<SkipReasonDialog> {
  final List<String> _reasons = [
    'Плохое самочувствие / тошнота',
    'Забыл(а) принять вовремя',
    'Препарата нет с собой',
    'Побочный эффект или непереносимость',
    'По рекомендации врача',
    'Другая причина',
  ];

  late String _selectedReason;
  final TextEditingController _customReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedReason = _reasons.first;
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantics = theme.extension<SemanticColors>() ?? SemanticColors.light;

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: semantics.warningBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.info_outline, color: semantics.warning, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Пропуск приёма',
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
              'Укажите причину пропуска для препарата «${widget.medicineName}». Запись сохранится в истории для лечащего врача.',
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodyMedium?.color ?? colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(_reasons.length, (index) {
              final reason = _reasons[index];
              final isSelected = _selectedReason == reason;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() {
                    _selectedReason = reason;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 18,
                        color: isSelected ? colorScheme.primary : colorScheme.outline,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.8),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (_selectedReason == 'Другая причина') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customReasonController,
                decoration: const InputDecoration(
                  hintText: 'Укажите причину...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Отмена',
            style: TextStyle(color: theme.textTheme.bodyMedium?.color ?? colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            final reason = _selectedReason == 'Другая причина' && _customReasonController.text.trim().isNotEmpty
                ? _customReasonController.text.trim()
                : _selectedReason;
            Navigator.of(context).pop(reason);
          },
          child: const Text('Подтвердить пропуск'),
        ),
      ],
    );
  }
}
