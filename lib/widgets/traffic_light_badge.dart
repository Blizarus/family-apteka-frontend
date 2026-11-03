import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TrafficLightBadge extends StatelessWidget {
  final String status;

  const TrafficLightBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final semantics = Theme.of(context).extension<SemanticColors>() ?? SemanticColors.light;
    Color bg;
    Color textColor;
    String label;

    switch (status) {
      case 'expiring':
        bg = semantics.warningBg;
        textColor = semantics.warningText;
        label = 'Скоро истечет';
        break;
      case 'expired':
        bg = semantics.dangerBg;
        textColor = semantics.dangerText;
        label = 'Просрочено!';
        break;
      case 'ok':
      default:
        bg = semantics.successBg;
        textColor = semantics.successText;
        label = 'В норме';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
