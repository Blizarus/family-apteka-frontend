import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/models/medicine.dart';
import 'package:frontend/models/notification_item.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/medicine_details_sheet.dart';
import 'package:frontend/widgets/notification_center_sheet.dart';

Widget createTestWidget({
  required Widget child,
  required ApiService apiService,
}) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(apiService: apiService),
      ),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('Shelf Life & Opening Unit Tests', () {
    test('Medicine model parses openedAt, daysAfterOpening and computes effectiveExpirationDate', () {
      final now = DateTime.now();
      final openedAtStr = now.subtract(const Duration(days: 5)).toIso8601String();

      final json = {
        'id': 10,
        'boxId': 1,
        'name': 'Капли назальные',
        'substance': 'Ксилометазолин',
        'form': 'Капли',
        'remaining': 10,
        'total': 10,
        'expiration_date': now.add(const Duration(days: 365)).toIso8601String(),
        'opened_at': openedAtStr,
        'days_after_opening': 30,
        'status': 'ok',
      };

      final med = Medicine.fromJson(json);

      expect(med.openedAt, isNotNull);
      expect(med.daysAfterOpening, 30);
      expect(med.effectiveExpirationDate, isNotNull);
      // Effective date should be openedAt + 30 days
      final expectedExp = med.openedAt!.add(const Duration(days: 30));
      expect(med.effectiveExpirationDate!.day, expectedExp.day);
      expect(med.isOpened, isTrue);
      expect(med.daysUntilExpiration, isNotNull);
      expect(med.daysUntilExpiration!, inInclusiveRange(24, 26));

      // Test toJson and copyWith
      final copy = med.copyWith(remaining: 8);
      expect(copy.remaining, 8);
      expect(copy.openedAt, med.openedAt);
      expect(copy.daysAfterOpening, 30);

      final map = copy.toJson();
      expect(map['opened_at'], isNotNull);
      expect(map['days_after_opening'], 30);
      expect(map['effective_expiration_date'], isNotNull);
    });

    test('Medicine status is expired if effective expiration date is in the past', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 40));
      final json = {
        'id': 11,
        'boxId': 1,
        'name': 'Сироп от кашля',
        'substance': 'Амброксол',
        'form': 'Сироп',
        'remaining': 5,
        'total': 10,
        'opened_at': pastDate.toIso8601String(),
        'days_after_opening': 30, // Expired 10 days ago
        'status': 'ok',
      };

      final med = Medicine.fromJson(json);
      expect(med.status, 'expired');
      expect(med.isExpired, isTrue);
    });

    test('ApiService.openMedicine and AppState.openMedicine update inventory', () async {
      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      await appState.loadInitialData();

      final firstMed = appState.medicines.first;
      expect(firstMed.openedAt, isNull);

      // Open the medicine with 14 days shelf life
      final updated = await appState.openMedicine(firstMed.id, daysAfterOpening: 14);

      expect(updated.id, firstMed.id);
      expect(updated.openedAt, isNotNull);
      expect(updated.daysAfterOpening, 14);
      expect(updated.effectiveExpirationDate, isNotNull);

      // Verify that AppState.medicines now holds the updated medicine
      final inState = appState.medicines.firstWhere((m) => m.id == firstMed.id);
      expect(inState.openedAt, isNotNull);
      expect(inState.daysAfterOpening, 14);
      expect(inState.isOpened, isTrue);
    });
  });

  group('Notification Model & State Tests', () {
    test('NotificationItem parses json and generates human readable defaults', () {
      final item1 = NotificationItem.fromJson({
        'id': 101,
        'type': 'expiry_critical',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(item1.id, 101);
      expect(item1.type, 'expiry_critical');
      expect(item1.title, 'Критический срок годности');
      expect(item1.message, contains('истёк'));
      expect(item1.isRead, isFalse);

      final item2 = NotificationItem.fromJson({
        'id': 102,
        'title': 'Пользовательский заголовок',
        'message': 'Пользовательский текст',
        'type': 'low_stock',
        'is_read': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(item2.title, 'Пользовательский заголовок');
      expect(item2.message, 'Пользовательский текст');
      expect(item2.isRead, isTrue);

      final json = item2.toJson();
      expect(json['id'], 102);
      expect(json['type'], 'low_stock');
      expect(json['is_read'], isTrue);
    });

    test('AppState notification flow: fetch, count unread, and delete', () async {
      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      await appState.fetchNotifications();

      expect(appState.notifications, isNotEmpty);
      final initialCount = appState.notifications.length;
      expect(appState.unreadNotificationsCount, greaterThanOrEqualTo(1));

      final firstId = appState.notifications.first.id;
      await appState.deleteNotification(firstId);

      expect(appState.notifications.length, initialCount - 1);
      expect(appState.notifications.any((n) => n.id == firstId), isFalse);
    });
  });

  group('Shelf Life & Notifications UI Widget Tests', () {
    testWidgets('MedicineDetailsSheet: displays "Вскрыть упаковку" button, dialog opens and performs open', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: apiService),
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      final unopenedMed = context.read<AppState>().medicines.firstWhere((m) => m.openedAt == null);
                      MedicineDetailsSheet.show(context, medicine: unopenedMed);
                    },
                    child: const Text('Открыть детали'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Advance time to allow loadInitialData to finish
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Открыть детали'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify "Вскрыть упаковку" button is visible
      final openButtonFinder = find.widgetWithText(OutlinedButton, 'Вскрыть упаковку');
      expect(openButtonFinder, findsOneWidget);

      // Tap "Вскрыть упаковку" -> confirmation dialog opens
      await tester.tap(openButtonFinder);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Сколько дней годен после вскрытия?'), findsOneWidget);
      expect(find.text('30'), findsWidgets); // Value or hint 30 days
      expect(find.text('Вскрыть'), findsOneWidget);

      // Submit dialog
      await tester.tap(find.text('Вскрыть'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify that shelf life card is now rendered with "Вскрыто:"
      expect(find.textContaining('Вскрыто:'), findsOneWidget);
      expect(find.textContaining('Годен до'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('MedicineDetailsSheet: displays red alert badge when shelf life after opening is expired', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      final expiredOpenedMed = Medicine(
        id: 99,
        boxId: 1,
        name: 'Глазные капли Просроченные',
        substance: 'Тобрекс',
        form: 'Капли',
        remaining: 5,
        total: 10,
        expiry: '10.2026',
        status: 'expired',
        openedAt: DateTime.now().subtract(const Duration(days: 45)),
        daysAfterOpening: 28, // Expired ~17 days ago
        effectiveExpirationDate: DateTime.now().subtract(const Duration(days: 17)),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: apiService),
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => MedicineDetailsSheet.show(context, medicine: expiredOpenedMed),
                    child: const Text('Открыть детали'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Открыть детали'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Check expired badge
      expect(find.text('ИСТЁК'), findsOneWidget);
      expect(find.text('СРОК ПОСЛЕ ВСКРЫТИЯ ИСТЁК'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('NotificationCenterSheet: renders notification items and deletes item on swipe or close button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: apiService),
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => NotificationCenterSheet.show(context),
                    child: const Text('Открыть уведомления'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Открыть уведомления'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Центр уведомлений'), findsOneWidget);
      expect(find.byType(NotificationCenterSheet), findsOneWidget);

      // Verify at least one notification card is shown
      expect(find.text('Срок годности (7 дней)'), findsOneWidget);

      // Find delete button on first card and tap it
      final closeIconButtons = find.byTooltip('Удалить');
      expect(closeIconButtons, findsWidgets);

      await tester.tap(closeIconButtons.first);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify item deleted
      expect(find.text('Срок годности (7 дней)'), findsNothing);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('NotificationCenterSheet: displays empty state when notifications list is empty', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: apiService),
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      // Clear notifications for empty state test
                      appState.notifications.clear();
                      NotificationCenterSheet.show(context);
                    },
                    child: const Text('Открыть уведомления'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Открыть уведомления'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Всё под контролем'), findsOneWidget);
    });

    testWidgets('HomeScreen: AppBar has bell icon with Badge and opens NotificationCenterSheet', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: apiService),
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify AppBar exists with title
      expect(find.text('Семейная Аптечка'), findsOneWidget);

      // Verify bell icon with tooltip "Уведомления"
      final bellFinder = find.byTooltip('Уведомления');
      expect(bellFinder, findsOneWidget);

      // Verify Badge exists
      expect(find.byType(Badge), findsWidgets);

      // Tap the bell button to open NotificationCenterSheet
      await tester.tap(bellFinder);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(NotificationCenterSheet), findsOneWidget);
      expect(find.text('Центр уведомлений'), findsOneWidget);
    });
  });
}
