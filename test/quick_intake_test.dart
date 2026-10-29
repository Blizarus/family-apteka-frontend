import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/medicine.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/widgets/medicine_details_sheet.dart';
import 'package:frontend/widgets/quick_intake_sheet.dart';
import 'package:provider/provider.dart';

Widget createTestApp(ApiService apiService) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(apiService: apiService),
      ),
    ],
    child: const FamilyAptekaApp(),
  );
}

Widget createSheetTestApp({
  required ApiService apiService,
  required Medicine medicine,
}) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(apiService: apiService),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: QuickIntakeSheet(medicine: medicine),
      ),
    ),
  );
}

Future<void> loginTestUser(WidgetTester tester) async {
  await tester.pumpWidget(createTestApp(ApiService(isMockMode: true)));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();

  await tester.tap(find.text('Войти в аккаунт'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Quick Intake (PRN) Feature Tests', () {
    // 1. Тест открытия шторки и отображения элементов
    testWidgets('1. Opening sheet and UI elements display: profile chips, stock, and stepper', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await loginTestUser(tester);

      // Переход на вкладку «Аптечка»
      await tester.tap(find.text('Аптечка'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Клик по карточке лекарства «Ибупрофен 400 мг»
      expect(find.text('Ибупрофен 400 мг'), findsOneWidget);
      await tester.tap(find.text('Ибупрофен 400 мг'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Карточка открыта, проверяем кнопку «Выпить сейчас»
      expect(find.byType(MedicineDetailsSheet), findsOneWidget);
      expect(find.text('Выпить сейчас'), findsOneWidget);

      // Клик на кнопку «Выпить сейчас»
      await tester.tap(find.text('Выпить сейчас'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Проверка открытия шторки QuickIntakeSheet
      expect(find.byType(QuickIntakeSheet), findsOneWidget);
      expect(find.text('Разовый приём'), findsOneWidget);

      // Проверка наличия чипсов членов семьи (активный профиль Анна выбран)
      expect(find.text('КТО ВЫПИЛ:'), findsOneWidget);
      expect(find.text('Анна'), findsOneWidget);

      // Проверка отображения текущего остатка препарата
      expect(find.textContaining('Остаток: 16 табл.'), findsOneWidget);

      // Проверка работы степпера количества
      // По умолчанию доза = 1 табл.
      expect(find.text('1 табл.'), findsWidgets);

      final addBtn = find.byIcon(Icons.add_circle_outline_rounded);
      final removeBtn = find.byIcon(Icons.remove_circle_outline_rounded);
      expect(addBtn, findsOneWidget);
      expect(removeBtn, findsOneWidget);

      // '+' увеличивает дозу: 1.0 -> 1.5 -> 2.0
      await tester.tap(addBtn);
      await tester.pump();
      expect(find.text('1.5 табл.'), findsWidgets);

      await tester.tap(addBtn);
      await tester.pump();
      expect(find.text('2 табл.'), findsWidgets);

      // '-' уменьшает дозу: 2.0 -> 1.5 -> 1.0 -> 0.5
      await tester.tap(removeBtn);
      await tester.pump();
      expect(find.text('1.5 табл.'), findsWidgets);

      await tester.tap(removeBtn);
      await tester.pump();
      expect(find.text('1 табл.'), findsWidgets);

      await tester.tap(removeBtn);
      await tester.pump();
      expect(find.text('0.5 табл.'), findsWidgets);

      // Нельзя уйти в <= 0 (кнопка деактивирована при <= 0.5)
      await tester.tap(removeBtn);
      await tester.pump();
      expect(find.text('0.5 табл.'), findsWidgets);
    });

    // 2. Тест валидации превышения остатка (Edge Case)
    testWidgets('2. Stock deficit validation: shows warning if quantity exceeds stock', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);

      // Лекарство с остатком 2 таблетки
      const lowStockMed = Medicine(
        id: 77,
        boxId: 1,
        name: 'Цитрамон П',
        substance: 'Ацетилсалициловая кислота + Парацетамол + Кофеин',
        form: 'Таблетки',
        remaining: 2,
        total: 10,
        expiry: '10.2028',
        status: 'ok',
      );

      await tester.pumpWidget(createSheetTestApp(
        apiService: apiService,
        medicine: lowStockMed,
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // При дозе 1 таблетка (по умолчанию) предупреждения нет
      expect(find.textContaining('превышает остаток в аптечке'), findsNothing);

      // Нажимаем '+' дважды, чтобы доза стала 2 табл. -> предупреждения все еще нет
      final addBtn = find.byIcon(Icons.add_circle_outline_rounded);
      await tester.tap(addBtn); // 1.5
      await tester.pump();
      await tester.tap(addBtn); // 2.0
      await tester.pump();
      expect(find.textContaining('превышает остаток в аптечке'), findsNothing);

      // Нажимаем '+' еще дважды: доза 3 таблетки при остатке 2
      await tester.tap(addBtn); // 2.5
      await tester.pump();
      await tester.tap(addBtn); // 3.0
      await tester.pump();

      // Должно отображаться предупреждение о нехватке остатка
      expect(find.textContaining('превышает остаток в аптечке'), findsOneWidget);
      expect(find.textContaining('Внимание: доза (3 табл.) превышает остаток в аптечке (2 табл.)'), findsOneWidget);
    });

    // 3. Тест выбора симптома
    testWidgets('3. Symptom selection: predefined symptom highlighted, custom reason shows text field', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);

      const testMed = Medicine(
        id: 1,
        boxId: 1,
        name: 'Ибупрофен 400 мг',
        substance: 'Ибупрофен',
        form: 'Таблетки',
        remaining: 16,
        total: 20,
        expiry: '11.2027',
        status: 'ok',
      );

      await tester.pumpWidget(createSheetTestApp(
        apiService: apiService,
        medicine: testMed,
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Клик по чипсу «⚡ Боль в животе» -> чипс подсвечивается (выбран)
      final bellyChip = find.widgetWithText(ChoiceChip, '⚡ Боль в животе');
      expect(bellyChip, findsOneWidget);
      expect(tester.widget<ChoiceChip>(bellyChip).selected, isTrue);

      // Клик по другому чипсу «🤕 Головная боль»
      final headChip = find.widgetWithText(ChoiceChip, '🤕 Головная боль');
      await tester.tap(headChip);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(headChip).selected, isTrue);
      expect(tester.widget<ChoiceChip>(bellyChip).selected, isFalse);

      // Возврат к «⚡ Боль в животе»
      await tester.tap(bellyChip);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(bellyChip).selected, isTrue);

      // До выбора «Своя причина» поле ввода отсутствует
      expect(find.byType(TextField), findsNothing);

      // Клик по «✏️ Своя причина» -> появляется поле текстового ввода
      final customChip = find.widgetWithText(ChoiceChip, '✏️ Своя причина');
      await tester.tap(customChip);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(customChip).selected, isTrue);

      // Проверка появления текстового поля и ввод причины
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Зубная боль после пломбирования');
      await tester.pump();
      expect(find.text('Зубная боль после пломбирования'), findsOneWidget);
    });

    // 4. Тест успешного подтверждения
    testWidgets('4. Successful intake confirmation: stock decrements, SnackBar appears, Today screen displays card', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await loginTestUser(tester);

      // Переход на вкладку «Аптечка»
      await tester.tap(find.text('Аптечка'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Исходный остаток Ибупрофена = 16
      expect(find.text('Ибупрофен 400 мг'), findsOneWidget);
      expect(find.text('16 / 20 шт.'), findsOneWidget);

      // Открытие карточки
      await tester.tap(find.text('Ибупрофен 400 мг'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Клик «Выпить сейчас»
      await tester.tap(find.text('Выпить сейчас'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(QuickIntakeSheet), findsOneWidget);

      // Выбираем симптом (по умолчанию «⚡ Боль в животе»)
      // Клик «⚡ Подтвердить приём»
      final confirmBtn = find.text('⚡ Подтвердить приём');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);

      // Ждем завершения запроса и закрытия шторки
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // Шторка закрылась
      expect(find.byType(QuickIntakeSheet), findsNothing);

      // Проверка появления всплывающего SnackBar с подтверждением и остатком 15
      expect(find.textContaining('✓ Принято: Ибупрофен 400 мг'), findsOneWidget);
      expect(find.textContaining('Остаток: 15'), findsOneWidget);

      // Закрываем детали лекарства
      Navigator.of(tester.element(find.byType(MedicineDetailsSheet))).pop();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Проверка, что в списке аптечки остаток уменьшился на 1 (15 / 20 шт.)
      expect(find.text('15 / 20 шт.'), findsOneWidget);

      // Переход на вкладку «Сегодня»
      await tester.tap(find.text('Сегодня'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Проверка, что появилась карточка со статусом «✓ Принято» и симптомом
      expect(find.textContaining('Боль в животе'), findsWidgets);
      expect(find.text('✓ Принято'), findsWidgets);
    });

    // 5. Тест Mock/Offline режима
    test('5. Mock/Offline mode: executes seamlessly when isMockMode = true without network', () async {
      final mockApi = ApiService(isMockMode: true);
      expect(mockApi.isMockMode, isTrue);

      final appState = AppState(apiService: mockApi);
      await appState.loadInitialData();

      final initialMedicine = appState.medicines.firstWhere((m) => m.id == 1);
      final initialRemaining = initialMedicine.remaining;

      // Вызов recordQuickIntake напрямую через AppState в Mock-режиме
      final result = await appState.recordQuickIntake(
        medicineId: 1,
        profileId: 1,
        quantity: 2.0,
        symptom: 'Тестовый оффлайн симптом',
      );

      expect(result['success'], isTrue);
      expect(result['remaining'], equals(initialRemaining - 2));

      // Проверка обновления данных в AppState
      final updatedMed = appState.medicines.firstWhere((m) => m.id == 1);
      expect(updatedMed.remaining, equals(initialRemaining - 2));

      // Проверка создания лога приёма в intakes
      final latestIntake = appState.intakes.first;
      expect(latestIntake.medicineId, equals(1));
      expect(latestIntake.taken, isTrue);
      expect(latestIntake.status, equals('taken'));
      expect(latestIntake.rule, contains('Тестовый оффлайн симптом'));
    });
  });
}
