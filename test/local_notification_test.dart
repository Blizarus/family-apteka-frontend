import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/screens/settings_screen.dart';
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

    test('6. DEF-57: buildAndroidNotificationDetails for alarm channel has persistent ringing flags (FLAG_INSISTENT, ongoing, autoCancel=false)', () {
      final details = service.buildAndroidNotificationDetails('alarm');
      expect(details.fullScreenIntent, isTrue);
      expect(details.category, equals(AndroidNotificationCategory.alarm));
      expect(details.visibility, equals(NotificationVisibility.public));
      expect(details.importance, equals(Importance.max));
      expect(details.autoCancel, isFalse);
      expect(details.ongoing, isTrue);
      expect(details.additionalFlags, isNotNull);
      expect(details.additionalFlags!.contains(4), isTrue); // FLAG_INSISTENT = 4

      final normalDetails = service.buildAndroidNotificationDetails('normal');
      expect(normalDetails.autoCancel, isTrue);
      expect(normalDetails.ongoing, isFalse);
      expect(normalDetails.additionalFlags, isNull);
    });

    testWidgets('7. DEF-57.5: SettingsScreen displays Battery Optimization tile and opens dialog', (tester) async {
      final storage = await StorageService.init();
      final apiService = ApiService(isMockMode: true, storageService: storage);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<ApiService>.value(value: apiService),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final tile = find.text('Работа будильника в спящем режиме');
      expect(tile, findsOneWidget);

      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.text('Спящий режим и батарея'), findsOneWidget);
      expect(find.textContaining('Doze Mode'), findsOneWidget);

      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();

      expect(find.text('Спящий режим и батарея'), findsNothing);
    });
  });
}
