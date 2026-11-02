import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/safety_alert_banner.dart';

void main() {
  group('SafetyAlertBanner Three Outcomes & Fail-Closed Tests', () {
    testWidgets('1. Fail-closed: missing or null is_safe does NOT default to true (safe)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafetyAlertBanner(
              safetyData: {},
            ),
          ),
        ),
      );

      // Не должно отображать зеленую плашку "Безопасно" при пустых данных!
      expect(find.textContaining('Безопасно'), findsNothing);
      expect(find.textContaining('проверить не удалось, обратитесь к врачу или провизору'), findsOneWidget);
    });

    testWidgets('2. Safe outcome: displays verified green banner and disclaimer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafetyAlertBanner(
              safetyData: {
                'status': 'safe',
                'is_safe': true,
                'has_critical': false,
                'warnings': [],
                'unverified_checks': [],
                'disclaimer': 'Автоматическая проверка взаимодействия лекарств носит информационный характер.',
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('Безопасно'), findsOneWidget);
      expect(find.textContaining('Автоматическая проверка взаимодействия'), findsOneWidget);
    });

    testWidgets('3. Conflict outcome: displays red/orange warning and clinical details', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafetyAlertBanner(
              safetyData: {
                'status': 'conflict',
                'is_safe': false,
                'has_critical': true,
                'warnings': [
                  'КРИТИЧЕСКАЯ ОПАСНОСТЬ: Аллергия на пенициллиновый ряд!',
                ],
                'unverified_checks': [],
                'disclaimer': 'При наличии сомнений обратитесь к врачу.',
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('КРИТИЧЕСКОЕ ПРЕДОСТЕРЕЖЕНИЕ'), findsOneWidget);
      expect(find.textContaining('Аллергия на пенициллиновый ряд'), findsOneWidget);
      expect(find.textContaining('обратитесь к врачу'), findsOneWidget);
    });

    testWidgets('4. Unverifiable outcome: displays amber notice, reasons and disclaimer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafetyAlertBanner(
              safetyData: {
                'status': 'unverifiable',
                'is_safe': false,
                'has_critical': false,
                'warnings': [],
                'unverified_checks': [
                  'У препарата не указаны МНН и код АТХ',
                  'Невозможно проверить аллергию на состав',
                ],
                'disclaimer': 'Автоматическая проверка взаимодействия лекарств носит информационный характер.',
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('проверить не удалось, обратитесь к врачу или провизору'), findsOneWidget);
      expect(find.textContaining('У препарата не указаны МНН и код АТХ'), findsOneWidget);
      expect(find.textContaining('Невозможно проверить аллергию на состав'), findsOneWidget);
      expect(find.textContaining('Автоматическая проверка взаимодействия'), findsOneWidget);
    });

    testWidgets('5. Fail-open case: custom drug without catalog link is unverifiable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafetyAlertBanner(
              safetyData: {
                'status': 'unverifiable',
                'is_safe': false,
                'has_critical': false,
                'warnings': [],
                'unverified_checks': [
                  'Препарат добавлен вручную и не привязан к справочнику',
                ],
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('проверить не удалось, обратитесь к врачу или провизору'), findsOneWidget);
      expect(find.textContaining('не привязан к справочнику'), findsOneWidget);
    });
  });
}
