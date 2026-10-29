import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/screens/notes_screen.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/screens/shopping_list_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/family_member_form.dart';
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
  testWidgets('ShoppingListScreen: groups by family member, swipe to purchase, undo and share', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await loginTestUser(tester);

    // Navigate to Notes -> Shopping subtab
    await tester.tap(find.text('Заметки'));
    await tester.pump(const Duration(milliseconds: 500));

    // Tap "🛒 В аптеку" subtab
    await tester.ensureVisible(find.text('🛒 В аптеку'));
    await tester.tap(find.text('🛒 В аптеку'));
    await tester.pump(const Duration(milliseconds: 500));

    // Scroll to "Открыть полный список покупок" and tap
    final openButtonFinder = find.text('Открыть полный список покупок');
    await tester.ensureVisible(openButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(openButtonFinder, findsOneWidget);

    // Open ShoppingListScreen
    await tester.tap(openButtonFinder);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify ShoppingListScreen loaded
    expect(find.byType(ShoppingListScreen), findsOneWidget);
    expect(find.text('Список покупок в аптеку'), findsOneWidget);

    // Verify groups and source badges
    expect(find.text('Для Анны (ОРВИ)'), findsOneWidget);
    expect(find.text('Для Михаила (Гипертензия)'), findsOneWidget);
    expect(find.text('Общие'), findsOneWidget);

    // Test Share button dialog
    await tester.tap(find.byTooltip('Поделиться списком'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Список для отправки'), findsOneWidget);
    expect(find.textContaining('Семейная Аптечка'), findsWidgets);

    // Close share dialog
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();

    // Test manual item add
    await tester.tap(find.text('Добавить в список'));
    await tester.pumpAndSettle();
    expect(find.text('НАИМЕНОВАНИЕ ПРЕПАРАТА'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Мирамистин 150мл');
    await tester.pump();

    final saveButton = find.text('Сохранить в список');
    await tester.ensureVisible(saveButton);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(saveButton);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Мирамистин 150мл'), findsOneWidget);

    // Test swipe right to purchase on the first item
    final dismissibleFinder = find.byType(Dismissible).first;
    await tester.fling(dismissibleFinder, const Offset(600, 0), 2000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify SnackBar appears with undo
    expect(find.text('Отмена'), findsOneWidget);
    expect(find.textContaining('куплен и добавлен в аптечку'), findsOneWidget);

    // Clear SnackBar
    ScaffoldMessenger.of(tester.element(find.byType(ShoppingListScreen))).clearSnackBars();
    await tester.pump(const Duration(milliseconds: 200));

    // Expand purchased section
    final purchasedHeader = find.textContaining('Куплено (');
    expect(purchasedHeader, findsOneWidget);
    await tester.tap(purchasedHeader);
    await tester.pump(const Duration(milliseconds: 500));

    // Item should now be in purchased section with "Вернуть" button
    expect(find.text('Вернуть'), findsWidgets);

    // Tap "Вернуть" to restore item
    await tester.tap(find.text('Вернуть').first);
    await tester.pump(const Duration(milliseconds: 500));

    // Item restored back to active list
    expect(find.text('Мирамистин 150мл'), findsOneWidget);

    // Go back to notes
    Navigator.of(tester.element(find.byType(ShoppingListScreen))).pop();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NotesScreen), findsOneWidget);
  });

  testWidgets('SettingsScreen: opens from Family tab, updates times and sync settings', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await loginTestUser(tester);

    // Navigate to Family Tab
    await tester.tap(find.text('Семья'));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify settings gear button in header
    expect(find.byTooltip('Настройки приложения'), findsOneWidget);
    await tester.tap(find.byTooltip('Настройки приложения'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify SettingsScreen is pushed
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('ВРЕМЯ ПРИЁМОВ ПО УМОЛЧАНИЮ'), findsOneWidget);
    expect(find.text('УВЕДОМЛЕНИЯ И НАПОМИНАНИЯ'), findsOneWidget);
    expect(find.text('СИНХРОНИЗАЦИЯ И СЕРВЕР'), findsOneWidget);
    expect(find.text('КОНФИДЕНЦИАЛЬНОСТЬ И БЕЗОПАСНОСТЬ (152-ФЗ)'), findsOneWidget);

    // Test server preset switch (in Sync block)
    final mirrorChipFinder = find.text('🌐 bluzaus.swtest.ru зеркало');
    await tester.ensureVisible(mirrorChipFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(mirrorChipFinder);
    await tester.pump();
    expect(find.text('http://bluzaus.ru.swtest.ru/api'), findsOneWidget);

    // Test connection check
    final checkButtonFinder = find.text('Проверить связь с сервером');
    await tester.ensureVisible(checkButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(checkButtonFinder);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Связь успешно установлена (200 OK)'), findsOneWidget);

    // Test Privacy policy dialog
    final privacyFinder = find.text('Политика обработки данных');
    await tester.ensureVisible(privacyFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(privacyFinder);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Политика обработки ПДн'), findsOneWidget);
    expect(find.textContaining('152-ФЗ РФ'), findsWidgets);

    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();

    // Test About Application section
    await tester.drag(find.byType(SettingsScreen), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('О ПРИЛОЖЕНИИ'), findsOneWidget);
    expect(find.text('Версия 1.0.0-beta (Сборка 2026.1)'), findsOneWidget);

    // Go back
    Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('FamilyMemberFormSheet: opens from profile card edit and adds allergy tag', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await loginTestUser(tester);

    // Navigate to Family Tab
    await tester.tap(find.text('Семья'));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify edit icon button exists on profile cards
    expect(find.byTooltip('Редактировать профиль'), findsWidgets);

    // Tap first edit icon
    await tester.tap(find.byTooltip('Редактировать профиль').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify FamilyMemberFormSheet opened in editing mode
    expect(find.byType(FamilyMemberFormSheet), findsOneWidget);
    expect(find.text('Редактирование профиля'), findsOneWidget);
    expect(find.text('АЛЛЕРГИИ И НЕПЕРЕНОСИМОСТИ (CDS)'), findsOneWidget);

    // Add unique allergy preset
    await tester.tap(find.text('+ Лактоза'));
    await tester.pump();
    expect(find.text('Лактоза'), findsOneWidget);

    // Save profile
    final saveButton = find.text('Сохранить профиль');
    await tester.ensureVisible(saveButton);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(saveButton);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify allergy appears on card in family screen
    expect(find.text('Лактоза'), findsOneWidget);
  });
}
