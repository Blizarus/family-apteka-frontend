import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/local_notification_service.dart';
import 'package:frontend/services/storage_service.dart';
import 'package:frontend/widgets/notification_permission_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalNotificationService Tests', () {
    late LocalNotificationService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      LocalNotificationService.resetInstanceForTesting();
      service = LocalNotificationService(mock: true);
    });

    test('1. Initialize service sets isInitialized flag to true', () async {
      expect(service.isInitialized, isFalse);
      final ok = await service.initialize();
      expect(ok, isTrue);
      expect(service.isInitialized, isTrue);
    });

    test('2. requestPermissions succeeds in mock/test mode', () async {
      final granted = await service.requestPermissions();
      expect(granted, isTrue);
    });

    test('3. Scheduling, cancelling, and clear reminders complete without errors', () async {
      await service.initialize();

      await service.scheduleIntakeReminder(
        id: 101,
        title: 'Приём Парацетамола',
        body: '1 таблетка после еды',
        scheduledDate: DateTime.now().add(const Duration(hours: 2)),
      );

      await service.cancelReminder(101);
      await service.cancelAll();
    });

    test('4. AppState loads intakes and integrates with reminder lifecycle (DEF-17 & DEF-19)', () async {
      final storage = await StorageService.init();
      final apiService = ApiService(isMockMode: true, storageService: storage);
      final appState = AppState(apiService: apiService);

      await appState.loadIntakes();
      expect(appState.intakes, isNotEmpty);

      final firstId = appState.intakes.first.id;
      final takenOk = await appState.markIntakeTaken(firstId);
      expect(takenOk, isTrue);

      final undoRes = await appState.undoIntake(firstId);
      expect(undoRes, isNotNull);
      expect(appState.intakes.firstWhere((i) => i.id == firstId).isTaken, isFalse);
    });

    testWidgets('5. NotificationPermissionDialog displays rationale and handles confirmation', (tester) async {
      final storage = await StorageService.init();
      await storage.setNotificationRationaleShown(false);

      bool? granted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  granted = await NotificationPermissionDialog.showIfNeeded(
                    ctx,
                    storageService: storage,
                    notificationService: service,
                  );
                },
                child: const Text('Ask Permission'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ask Permission'));
      await tester.pumpAndSettle();

      expect(find.text('Напоминания о лекарствах'), findsOneWidget);
      expect(find.text('Канал «Будильник»'), findsOneWidget);
      expect(find.text('Действия в шторке'), findsOneWidget);

      await tester.tap(find.text('Разрешить'));
      await tester.pumpAndSettle();

      expect(granted, isTrue);
      expect(await storage.hasNotificationRationaleShown(), isTrue);
    });
  });
}
