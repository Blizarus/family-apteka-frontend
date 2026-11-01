import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/models/medicine.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/medicine_details_sheet.dart';
import 'package:frontend/widgets/move_medicine_sheet.dart';

Widget buildTestApp({
  required Widget child,
  required AppState appState,
}) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: appState.apiService),
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Medicine Model: isLowStock & Thresholds', () {
    test('Default threshold (3): calculates isLowStock correctly', () {
      const medStock3 = Medicine(
        id: 101,
        boxId: 1,
        name: 'Тест 3 шт.',
        substance: 'Субстанция',
        form: 'Таблетки',
        remaining: 3,
        total: 10,
        expiry: '12.2028',
        status: 'ok',
      );
      expect(medStock3.lowStockThreshold, 3);
      expect(medStock3.isLowStock, isTrue);

      final medStock2 = medStock3.copyWith(remaining: 2);
      expect(medStock2.isLowStock, isTrue);

      final medStock1 = medStock3.copyWith(remaining: 1);
      expect(medStock1.isLowStock, isTrue);

      final medStock4 = medStock3.copyWith(remaining: 4);
      expect(medStock4.isLowStock, isFalse);

      final medStock0 = medStock3.copyWith(remaining: 0);
      expect(medStock0.isLowStock, isFalse);

      final medStockNegative = medStock3.copyWith(remaining: -1);
      expect(medStockNegative.isLowStock, isFalse);
    });

    test('Custom threshold: calculates isLowStock with custom lowStockThreshold', () {
      const medCustom5 = Medicine(
        id: 102,
        boxId: 1,
        name: 'Тест Порог 5',
        substance: 'Субстанция',
        form: 'Таблетки',
        remaining: 5,
        total: 20,
        expiry: '12.2028',
        status: 'ok',
        lowStockThreshold: 5,
      );
      expect(medCustom5.lowStockThreshold, 5);
      expect(medCustom5.isLowStock, isTrue);

      final medStock4 = medCustom5.copyWith(remaining: 4);
      expect(medStock4.isLowStock, isTrue);

      final medStock6 = medCustom5.copyWith(remaining: 6);
      expect(medStock6.isLowStock, isFalse);

      // Custom threshold = 1
      final medCustom1 = medCustom5.copyWith(lowStockThreshold: 1, remaining: 2);
      expect(medCustom1.isLowStock, isFalse);
      final medCustom1Low = medCustom1.copyWith(remaining: 1);
      expect(medCustom1Low.isLowStock, isTrue);
    });

    test('fromJson & toJson serialization preserves lowStockThreshold', () {
      final json = {
        'id': 201,
        'medicine_box_id': 2,
        'name': 'Сериализация Тест',
        'substance': 'Вещество',
        'form': 'Капсулы',
        'remaining': 2,
        'total': 10,
        'expiry': '10.2029',
        'status': 'ok',
        'low_stock_threshold': 4,
      };

      final parsed = Medicine.fromJson(json);
      expect(parsed.id, 201);
      expect(parsed.boxId, 2);
      expect(parsed.remaining, 2);
      expect(parsed.lowStockThreshold, 4);
      expect(parsed.isLowStock, isTrue);

      final outJson = parsed.toJson();
      expect(outJson['low_stock_threshold'], 4);
      expect(outJson['remaining'], 2);
    });
  });

  group('2. ApiService & AppState: moveMedicine & Low Stock Alerts', () {
    test('ApiService.moveMedicine updates boxId in mock mode', () async {
      final apiService = ApiService(isMockMode: true);
      final updated = await apiService.moveMedicine(1, 2);

      expect(updated.id, 1);
      expect(updated.boxId, 2);

      final medicines = await apiService.getMedicines();
      final med1 = medicines.firstWhere((m) => m.id == 1);
      expect(med1.boxId, 2);
    });

    test('AppState.moveMedicine updates local medicines list and inserts notification', () async {
      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);
      await appState.loadInitialData();

      final initialMed1 = appState.medicines.firstWhere((m) => m.id == 1);
      expect(initialMed1.boxId, 1);

      final targetBox = appState.boxes.firstWhere((b) => b.id == 2);

      final success = await appState.moveMedicine(1, 2);
      expect(success, isTrue);

      final updatedMed1 = appState.medicines.firstWhere((m) => m.id == 1);
      expect(updatedMed1.boxId, 2);

      // Verify notification added
      expect(appState.notifications.isNotEmpty, isTrue);
      final moveNotification = appState.notifications.firstWhere(
        (n) => n.title == 'Перемещение препарата',
      );
      expect(moveNotification.message, contains(updatedMed1.name));
      expect(moveNotification.message, contains(targetBox.name));
    });

    test('AppState generates low stock notifications automatically on load', () async {
      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);
      await appState.loadInitialData();

      // Check if low stock notification exists
      final lowStockNotifs = appState.notifications.where((n) => n.type == 'low_stock').toList();
      expect(lowStockNotifs.isNotEmpty, isTrue);
      expect(
        lowStockNotifs.any((n) => n.message.contains('Осталось всего')),
        isTrue,
      );
    });
  });

  group('3. MoveMedicineSheet Widget Tests', () {
    testWidgets('Renders available target boxes (excluding current) and moves medicine', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);
      await tester.runAsync(() async {
        await appState.loadInitialData();
      });

      final med = appState.medicines.firstWhere((m) => m.id == 1 && m.boxId == 1);

      await tester.pumpWidget(
        buildTestApp(
          appState: appState,
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => MoveMedicineSheet.show(context, medicine: med),
                child: const Text('Open Move Sheet'),
              );
            },
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Move Sheet'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(MoveMedicineSheet), findsOneWidget);
      expect(find.text('Перемещение препарата'), findsOneWidget);
      expect(find.text('Препарат: ${med.name}'), findsOneWidget);
      expect(find.text('ВЫБЕРИТЕ ЦЕЛЕВУЮ АПТЕЧКУ'), findsOneWidget);

      // Box 1 should NOT be in the target selectable list
      // Target boxes (Box 2: Автомобильная) should be present (name and boxType badge)
      expect(find.text('Автомобильная'), findsNWidgets(2));

      // Target box icons and descriptions should be rendered
      final targetBox2 = appState.boxes.firstWhere((b) => b.id == 2);
      expect(find.text(targetBox2.icon), findsOneWidget);
      if (targetBox2.location.isNotEmpty) {
        expect(find.text(targetBox2.location), findsOneWidget);
      }

      // Tap on Box 2
      await tester.tap(find.text('Автомобильная').first);
      await tester.pump(const Duration(milliseconds: 300));

      // Tap submit button "Переместить препарат"
      final submitButton = find.widgetWithText(ElevatedButton, 'Переместить препарат');
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 4)); // Allow SnackBar timer to complete

      // Check medicine boxId in state has been updated to 2
      final updatedMed = appState.medicines.firstWhere((m) => m.id == med.id);
      expect(updatedMed.boxId, 2);
    });
  });

  group('4. MedicineDetailsSheet Widget Tests: Low Stock Badge & Move Button', () {
    testWidgets('Shows Low Stock warning badge and + В список покупок button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);
      await tester.runAsync(() async {
        await appState.loadInitialData();
      });

      // Medicine with low stock: remaining = 2, threshold = 3
      const lowStockMed = Medicine(
        id: 999,
        boxId: 1,
        name: 'Парацетамол Ультра',
        substance: 'Парацетамол',
        form: 'Таблетки',
        remaining: 2,
        total: 10,
        expiry: '12.2028',
        status: 'ok',
        lowStockThreshold: 3,
        quantityUnit: 'табл.',
      );

      // Add to state
      appState.medicines.add(lowStockMed);

      await tester.pumpWidget(
        buildTestApp(
          appState: appState,
          child: const MedicineDetailsSheet(medicine: lowStockMed),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Low Stock warning banner
      expect(find.textContaining('Заканчивается: осталось 2'), findsOneWidget);

      // Verify quick add to shopping list button
      final addShoppingBtn = find.text('+ В список покупок');
      expect(addShoppingBtn, findsOneWidget);

      // Tap on + В список покупок
      await tester.tap(addShoppingBtn);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 4)); // Allow SnackBar timer to complete

      // Verify shopping item added to appState
      expect(
        appState.shoppingItems.any((item) => item.name == 'Парацетамол Ультра'),
        isTrue,
      );

      // Verify "Переместить в другую аптечку" button is present with correct icon
      final moveBtn = find.widgetWithText(OutlinedButton, 'Переместить в другую аптечку');
      expect(moveBtn, findsOneWidget);
      expect(find.byIcon(Icons.drive_file_move_outlined), findsOneWidget);

      // Tap on "Переместить в другую аптечку" and verify MoveMedicineSheet opens
      await tester.tap(moveBtn);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(MoveMedicineSheet), findsOneWidget);
    });

    testWidgets('Does not show Low Stock warning badge when medicine stock is normal', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);
      await tester.runAsync(() async {
        await appState.loadInitialData();
      });

      // Medicine with normal stock: remaining = 16, threshold = 3
      final normalMed = appState.medicines.firstWhere((m) => m.remaining > 5);

      await tester.pumpWidget(
        buildTestApp(
          appState: appState,
          child: MedicineDetailsSheet(medicine: normalMed),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Low Stock warning banner is NOT shown
      expect(find.textContaining('Заканчивается: осталось'), findsNothing);
      expect(find.text('+ В список покупок'), findsNothing);

      // But "Переместить в другую аптечку" button is still present
      expect(find.widgetWithText(OutlinedButton, 'Переместить в другую аптечку'), findsOneWidget);
    });
  });
}
