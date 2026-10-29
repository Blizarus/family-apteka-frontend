import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/screens/admin_panel_screen.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:provider/provider.dart';

Widget createTestApp(ApiService apiService, {User? initialUser}) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<AppState>(
        create: (_) {
          final state = AppState(apiService: apiService);
          if (initialUser != null) {
            state.setCurrentUser(initialUser);
          }
          return state;
        },
      ),
    ],
    child: const FamilyAptekaApp(),
  );
}

Future<void> loginAsAdmin(WidgetTester tester, ApiService apiService) async {
  await tester.pumpWidget(createTestApp(apiService));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  // Fill admin credentials
  final emailFinder = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == 'example@family.test',
  );
  final passFinder = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == '••••••••',
  );

  await tester.enterText(emailFinder, 'admin@family.test');
  await tester.enterText(passFinder, 'admin123');
  await tester.pump(const Duration(milliseconds: 200));

  await tester.tap(find.text('Войти в аккаунт'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> openAdminPanel(WidgetTester tester) async {
  await tester.tap(find.text('Семья'));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.byTooltip('Настройки приложения'));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));

  final adminCardFinder = find.text('🛡️ Панель администратора безопасности');
  await tester.ensureVisible(adminCardFinder);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(adminCardFinder);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('Admin Security Panel (LR 2 Table 1, rows 4-5)', () {
    testWidgets('1. Admin login activates admin mode, opens AdminPanel from Settings', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      await loginAsAdmin(tester, apiService);

      // Verify active user is admin
      final appState = tester.element(find.byType(FamilyAptekaApp)).read<AppState>();
      expect(appState.currentUser?.isAdmin, isTrue);
      expect(appState.currentUser?.email, 'admin@family.test');

      // Navigate to Settings Screen
      await tester.tap(find.text('Семья'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byTooltip('Настройки приложения'), findsOneWidget);
      await tester.tap(find.byTooltip('Настройки приложения'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SettingsScreen), findsOneWidget);

      // Verify Admin Panel card is present
      final adminCardFinder = find.text('🛡️ Панель администратора безопасности');
      await tester.ensureVisible(adminCardFinder);
      await tester.pump(const Duration(milliseconds: 300));
      expect(adminCardFinder, findsOneWidget);

      // Tap card to open AdminPanelScreen
      await tester.tap(adminCardFinder);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify AdminPanelScreen opened
      expect(find.byType(AdminPanelScreen), findsOneWidget);
      expect(find.text('Панель администратора'), findsOneWidget);
      expect(find.text('Пользователи'), findsOneWidget);
      expect(find.text('Справочник ГРЛС'), findsOneWidget);
    });

    testWidgets('2. Users tab: lists users, blocks with confirmation dialog and revokes sessions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      await loginAsAdmin(tester, apiService);

      // Open Settings -> Admin Panel
      await openAdminPanel(tester);

      // Check users are loaded
      expect(find.text('anna@family.test'), findsOneWidget);
      expect(find.text('guest_test@family.test'), findsOneWidget);
      expect(find.text('admin@family.test'), findsOneWidget);

      // Active status chips
      expect(find.text('Активен'), findsWidgets);

      // Find "Заблокировать" button for guest_test@family.test or anna@family.test
      final blockButtons = find.widgetWithText(OutlinedButton, 'Заблокировать');
      expect(blockButtons, findsWidgets);

      // Tap block on first non-admin user
      await tester.tap(blockButtons.first);
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Confirmation Dialog appears
      expect(find.text('Блокировка пользователя'), findsOneWidget);
      expect(find.textContaining('Все активные Sanctum-токены и сессии'), findsOneWidget);

      // Confirm block
      await tester.tap(find.widgetWithText(ElevatedButton, 'Заблокировать'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify blocked status chip appears
      expect(find.text('Заблокирован'), findsOneWidget);

      // Now unblock user
      final unblockButton = find.widgetWithText(OutlinedButton, 'Разблокировать');
      expect(unblockButton, findsOneWidget);
      await tester.tap(unblockButton);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify unblocked
      expect(find.text('Активен'), findsWidgets);
    });

    testWidgets('3. GRLS tab: searches catalog and adds new medicine via FAB', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      await loginAsAdmin(tester, apiService);

      // Open Admin Panel
      await openAdminPanel(tester);

      // Switch to "Справочник ГРЛС" Tab
      await tester.tap(find.text('Справочник ГРЛС'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify medicines loaded (e.g. Ибупрофен, Амоксициллин)
      expect(find.text('Ибупрофен'), findsOneWidget);
      expect(find.text('Амоксициллин'), findsOneWidget);

      // Test catalog search
      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Поиск по ГРЛС (название, МНН, штрихкод)...',
      );
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Ибупрофен');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('МНН: Ибупрофен • Таблетки 400 мг'), findsOneWidget);
      expect(find.text('Амоксициллин'), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Амоксициллин'), findsOneWidget);

      // Open Add Medicine Dialog via FAB
      final fabFinder = find.widgetWithText(FloatingActionButton, 'Добавить препарат');
      expect(fabFinder, findsOneWidget);
      await tester.tap(fabFinder);
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Add Medicine Dialog
      expect(find.text('Добавить препарат в ГРЛС'), findsOneWidget);

      // Fill form
      final tradeNameInput = find.widgetWithText(TextFormField, 'Торговое наименование *');
      final innInput = find.widgetWithText(TextFormField, 'МНН (Действующее вещество) *');
      final barcodeInput = find.widgetWithText(TextFormField, 'Штрихкод / EAN-13 *');
      final dosageInput = find.widgetWithText(TextFormField, 'Дозировка *');

      await tester.enterText(tradeNameInput, 'Парацетамол-МГУ');
      await tester.enterText(innInput, 'Парацетамол');
      await tester.enterText(barcodeInput, '4609876543210');
      await tester.enterText(dosageInput, '500 мг');
      await tester.pump(const Duration(milliseconds: 200));

      // Submit form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Сохранить в ГРЛС'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify new medicine is added to the list
      expect(find.text('Парацетамол-МГУ'), findsOneWidget);
      expect(find.text('МНН: Парацетамол • Таблетки 500 мг'), findsOneWidget);
    });
  });
}
