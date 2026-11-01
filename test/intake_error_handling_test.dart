import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/intake_log.dart';
import 'package:frontend/models/medicine.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/screens/today_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/widgets/quick_intake_sheet.dart';
import 'package:provider/provider.dart';

Widget createTodayTestApp({required AppState state}) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: state.apiService),
      ChangeNotifierProvider<AppState>.value(value: state),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const TodayScreen(),
    ),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Intake Error Handling & Double Tap Protection Tests', () {
    // -------------------------------------------------------------
    // ТЕСТ 1: Блокировка повторного нажатия во время отправки (Double-tap protection)
    // -------------------------------------------------------------
    test('1. Double-tap protection: blocks duplicate concurrent intake requests in AppState', () async {
      final apiService = ApiService(isMockMode: true);
      final state = AppState(apiService: apiService);
      await state.loadInitialData();

      expect(state.isIntakeProcessing(102), isFalse);
      expect(state.isTakingLog, isFalse);

      // Запускаем два параллельных запроса на один и тот же id
      final future1 = state.takeIntakeLog(102);
      expect(state.isIntakeProcessing(102), isTrue);
      expect(state.isTakingLog, isTrue);

      // Второй запрос во время обработки первого должен быть заблокирован и вернуть null
      final future2 = state.takeIntakeLog(102);
      final result2 = await future2;
      expect(result2, isNull);

      final result1 = await future1;
      expect(result1, isNotNull);
      expect(state.isIntakeProcessing(102), isFalse);
      expect(state.isTakingLog, isFalse);
    });

    testWidgets('1b. Double-tap UI: disables button and ignores repeated taps while processing', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final state = AppState(apiService: apiService);
      await tester.runAsync(() async {
        await state.loadInitialData();
      });

      await tester.pumpWidget(createTodayTestApp(state: state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final takeButton = find.byType(ElevatedButton).first;
      expect(state.isIntakeProcessing(102), isFalse);

      // Первый тап активирует приём
      await tester.tap(takeButton);
      await tester.pump();

      // Проверяем, что в состоянии зафиксирована обработка
      expect(state.isTakingLog, isTrue);
      expect(state.isIntakeProcessing(102), isTrue);

      // Повторный тап во время обработки игнорируется (onPressed == null, повторный запрос заблокирован)
      await tester.tap(takeButton, warnIfMissed: false);
      await tester.pump();

      // Дожидаемся завершения
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(state.isTakingLog, isFalse);
      expect(state.isIntakeProcessing(102), isFalse);
    });

    // -------------------------------------------------------------
    // ТЕСТ 2: Появление диалога подтверждения при нехватке остатка (409)
    // и успешная повторная отправка с confirm_without_stock: true
    // -------------------------------------------------------------
    test('2. ApiService: throws StockConfirmationRequiredException on 0 stock without confirmation', () async {
      final apiService = ApiService(isMockMode: true);

      // Добавляем лог с остатком 0
      final zeroStockLog = IntakeLog(
        id: 701,
        profileId: 1,
        medicineName: 'Аспирин Кардио 100 мг',
        form: 'Таблетки',
        time: '12:00',
        rule: 'После еды • 1 таб.',
        taken: false,
        status: 'scheduled',
        course: 'Кардио',
        remaining: 0,
      );
      apiService.addMockIntake(zeroStockLog);

      // Вызов без подтверждения должен бросить исключение
      expect(
        () => apiService.takeIntakeLog(701, confirmWithoutStock: false),
        throwsA(isA<StockConfirmationRequiredException>()),
      );

      // Вызов с подтверждением должен успешно выполниться
      final res = await apiService.takeIntakeLog(701, confirmWithoutStock: true);
      expect(res['stock_warning'], isTrue);
      expect(res['message'], contains('без списания остатка'));
    });

    testWidgets('2b. TodayScreen: out-of-stock dialog appears on 409 and confirm_without_stock marks taken', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      // Устанавливаем текущему приёму (id 102) нулевой остаток
      apiService.setMockIntakeRemaining(102, 0.0);

      final state = AppState(apiService: apiService);
      await tester.runAsync(() async {
        await state.loadInitialData();
      });

      await tester.pumpWidget(createTodayTestApp(state: state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Амоксициллин 500 мг'), findsOneWidget);

      // Нажимаем «Принято»
      final takeBtn = find.widgetWithText(ElevatedButton, 'Принято').first;
      await tester.tap(takeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Проверяем, что открылся диалог предупреждения об отсутствии остатка
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('⚠️ Препарат закончился в аптечке'), findsOneWidget);
      expect(find.textContaining('В аптечке недостаточно таблеток для списания остатка'), findsOneWidget);
      expect(find.text('Зафиксировать приём'), findsOneWidget);
      expect(find.text('+ В список покупок'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);

      // Нажимаем «Зафиксировать приём»
      await tester.tap(find.text('Зафиксировать приём'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Диалог должен закрыться
      expect(find.byType(AlertDialog), findsNothing);

      // Приём успешно зафиксирован
      final updatedLog = state.intakes.firstWhere((i) => i.id == 102);
      expect(updatedLog.isTaken, isTrue);

      // Отображается тост подтверждения
      expect(find.textContaining('Приём зафиксирован без списания остатка'), findsWidgets);
    });

    testWidgets('2c. Out-of-stock dialog: "+ В список покупок" adds item to shopping list', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      apiService.setMockIntakeRemaining(102, 0.0);

      final state = AppState(apiService: apiService);
      await tester.runAsync(() async {
        await state.loadInitialData();
      });

      await tester.pumpWidget(createTodayTestApp(state: state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Нажимаем «Принято»
      await tester.tap(find.widgetWithText(ElevatedButton, 'Принято').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Диалог открыт
      expect(find.byType(AlertDialog), findsOneWidget);

      // Нажимаем «+ В список покупок»
      await tester.tap(find.text('+ В список покупок'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Диалог закрылся
      expect(find.byType(AlertDialog), findsNothing);

      // Препарат добавлен в список покупок
      final inShopping = state.shoppingItems.any((item) => item.name.contains('Амоксициллин'));
      expect(inShopping, isTrue);
      expect(find.textContaining('добавлен в список покупок'), findsWidgets);
    });

    // -------------------------------------------------------------
    // ТЕСТ 3: Корректная обработка ответа «уже принято»
    // -------------------------------------------------------------
    test('3. Already taken handling: ApiService returns already_taken and does not throw', () async {
      final apiService = ApiService(isMockMode: true);

      // intake id 101 уже имеет статус taken: true в _mockIntakes
      final res = await apiService.takeIntakeLog(101);
      expect(res['already_taken'], isTrue);
      expect(res['message'], contains('уже был зафиксирован ранее'));
    });

    test('3b. Already taken handling: AppState processes already taken without error', () async {
      final apiService = ApiService(isMockMode: true);
      final state = AppState(apiService: apiService);
      await state.loadInitialData();

      // Вызываем приём для уже принятого лога (id 101)
      final res = await state.takeIntakeLog(101);
      expect(res, isNotNull);
      expect(res!['already_taken'], isTrue);
      expect(res['message'], contains('уже был зафиксирован ранее'));
    });

    // -------------------------------------------------------------
    // ТЕСТ 4: Quick Intake (разовый приём) с confirm_without_stock
    // -------------------------------------------------------------
    test('4. Quick intake: handles out of stock and confirms without stock via quickIntake alias', () async {
      final apiService = ApiService(isMockMode: true);

      // Добавляем лекарство с остатком 0
      const emptyMed = Medicine(
        id: 990,
        boxId: 1,
        name: 'Парацетамол Экстра',
        substance: 'Парацетамол',
        form: 'Таблетки',
        remaining: 0,
        total: 10,
        expiry: '12.2028',
        status: 'expired',
      );
      await apiService.addMedicine(emptyMed.toJson());

      // Попытка разового приёма без подтверждения должна вызвать исключение
      expect(
        () => apiService.quickIntake(
          medicineId: 990,
          profileId: 1,
          quantity: 1.0,
          confirmWithoutStock: false,
        ),
        throwsA(isA<StockConfirmationRequiredException>()),
      );

      // Приём с confirmWithoutStock: true успешно записывается
      final result = await apiService.quickIntake(
        medicineId: 990,
        profileId: 1,
        quantity: 1.0,
        confirmWithoutStock: true,
      );
      expect(result['success'], isTrue);
      expect(result['stock_warning'], isTrue);
    });

    testWidgets('4b. QuickIntakeSheet: shows OutOfStockConfirmationDialog on stock deficit', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      // Устанавливаем нулевой остаток для Ибупрофена (id 1)
      apiService.setMockMedicineRemaining(1, 0.0);

      final state = AppState(apiService: apiService);
      await tester.runAsync(() async {
        await state.loadInitialData();
      });

      final med = state.medicines.firstWhere((m) => m.id == 1);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: state.apiService),
            ChangeNotifierProvider<AppState>.value(value: state),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => QuickIntakeSheet.show(ctx, medicine: med),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Открываем шторку
      await tester.tap(find.text('Open Sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Нажимаем «Подтвердить приём»
      final confirmBtn = find.text('⚡ Подтвердить приём');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Появляется диалог предупреждения
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('⚠️ Препарат закончился в аптечке'), findsOneWidget);

      // Нажимаем «Зафиксировать приём»
      await tester.tap(find.text('Зафиксировать приём'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Диалог и шторка закрываются
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(QuickIntakeSheet), findsNothing);

      // Показывается SnackBar об успешном приёме без списания остатка
      expect(find.textContaining('Зафиксировано без списания остатка'), findsOneWidget);
    });
  });
}
