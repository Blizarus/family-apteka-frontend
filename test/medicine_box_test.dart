import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/main.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/screens/medicine_box_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/box_selector_dialog.dart';
import 'package:frontend/widgets/create_medicine_box_sheet.dart';

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
  group('Medicine Box Creation & Management Tests', () {
    testWidgets('1. CreateMedicineBoxSheet: validation, type selection, box creation and auto-selection', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await loginTestUser(tester);

      // Navigate to Medicine Box screen (Аптечка)
      await tester.tap(find.text('Аптечка'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(MedicineBoxScreen), findsOneWidget);

      // Initially selected box is "Домашняя аптечка"
      expect(find.text('Домашняя аптечка'), findsWidgets);

      // Tap on the box title dropdown in the header to open BoxSelectorSheet
      await tester.tap(find.text('Домашняя аптечка').first);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify BoxSelectorSheet is shown
      expect(find.byType(BoxSelectorSheet), findsOneWidget);
      expect(find.text('ВЫБЕРИТЕ ХРАНИЛИЩЕ'), findsOneWidget);
      expect(find.text('Создать новую аптечку'), findsOneWidget);

      // Tap "Создать новую аптечку"
      await tester.tap(find.text('Создать новую аптечку'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify CreateMedicineBoxSheet is shown
      expect(find.byType(CreateMedicineBoxSheet), findsOneWidget);
      expect(find.text('Новая аптечка'), findsOneWidget);
      expect(find.text('Создайте категорию для раздельного хранения медикаментов'), findsOneWidget);

      // 1. Try to submit without a name -> should validate and show error
      await tester.tap(find.text('✓ Создать аптечку'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Введите название аптечки'), findsOneWidget);

      // 2. Select box type: "Дорожная / Походная"
      final travelTypeFinder = find.text('Дорожная / Походная');
      expect(travelTypeFinder, findsOneWidget);
      await tester.tap(travelTypeFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // 3. Enter box name: "Походный рюкзак"
      final nameFieldFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Например, Дачная аптечка, Походный рюкзак...',
      );
      expect(nameFieldFinder, findsOneWidget);
      await tester.enterText(nameFieldFinder, 'Походный рюкзак');
      await tester.pump(const Duration(milliseconds: 200));

      // 4. Enter location: "Верхний клапан"
      final locationFieldFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Например, Шкаф в коридоре, полка 2, Бардачок...',
      );
      expect(locationFieldFinder, findsOneWidget);
      await tester.enterText(locationFieldFinder, 'Верхний клапан');
      await tester.pump(const Duration(milliseconds: 200));

      // 5. Submit form
      await tester.tap(find.text('✓ Создать аптечку'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify sheet is dismissed
      expect(find.byType(CreateMedicineBoxSheet), findsNothing);

      // Verify Toast message
      expect(find.text('✓ Аптечка «Походный рюкзак» успешно создана!'), findsOneWidget);

      // Verify active box is now "Походный рюкзак"
      final appState = tester.element(find.byType(FamilyAptekaApp)).read<AppState>();
      expect(appState.selectedBox?.name, 'Походный рюкзак');
      expect(appState.selectedBox?.boxType, 'travel');
      expect(appState.selectedBox?.location, 'Верхний клапан');
      expect(appState.selectedBox?.icon, '✈️');

      // Verify header updated on MedicineBoxScreen
      expect(find.text('Походный рюкзак'), findsWidgets);

      // Open BoxSelectorSheet again and verify all 3 boxes are listed
      await tester.tap(find.text('Походный рюкзак').first);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.descendant(of: find.byType(BoxSelectorSheet), matching: find.text('Домашняя аптечка')), findsOneWidget);
      expect(find.descendant(of: find.byType(BoxSelectorSheet), matching: find.text('Автомобильная')), findsOneWidget);
      expect(find.descendant(of: find.byType(BoxSelectorSheet), matching: find.text('Походный рюкзак')), findsOneWidget);

      // Switch back to "Домашняя аптечка"
      await tester.tap(find.descendant(of: find.byType(BoxSelectorSheet), matching: find.text('Домашняя аптечка')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(appState.selectedBox?.name, 'Домашняя аптечка');
    });

    test('2. Direct AppState methods: createMedicineBox and deleteMedicineBox', () async {
      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);
      await appState.loadInitialData();

      // Initial boxes: Home (id 1) and Car (id 2)
      expect(appState.boxes.length, 2);

      // Create new box
      final newBox = await appState.createMedicineBox(
        name: 'Дачная аптечка',
        boxType: 'home',
        description: 'Тумбочка в спальне',
      );

      expect(newBox, isNotNull);
      expect(newBox!.name, 'Дачная аптечка');
      expect(appState.boxes.length, 3);
      expect(appState.selectedBoxId, newBox.id);

      // Delete the newly created box
      await appState.deleteMedicineBox(newBox.id);
      expect(appState.boxes.length, 2);
      expect(appState.boxes.any((b) => b.id == newBox.id), isFalse);
      // Active box resets to first available
      expect(appState.selectedBoxId, appState.boxes.first.id);
    });
  });
}
