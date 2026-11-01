import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/screens/login_screen.dart';

Widget buildTestSettingsApp({
  required AppState appState,
  required ApiService apiService,
}) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: const MaterialApp(
      home: SettingsScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. ApiService & AppState: 152-FZ Account Management Logic', () {
    test('updatePassword validates current password and updates state in mock mode', () async {
      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      // Wrong current password
      final fail = await appState.updatePassword(
        currentPassword: 'wrong_pass',
        newPassword: 'new_secret_password_123',
        newPasswordConfirmation: 'new_secret_password_123',
      );
      expect(fail['success'], isFalse);
      expect(fail['message'], contains('Текущий пароль указан неверно'));

      // Correct current password
      final success = await appState.updatePassword(
        currentPassword: 'correct_password',
        newPassword: 'new_secret_password_123',
        newPasswordConfirmation: 'new_secret_password_123',
      );
      expect(success['success'], isTrue);
      expect(success['message'], contains('Пароль успешно изменен'));
    });

    test('exportPersonalData returns compliant DSAR JSON structure according to 152-FZ art. 14', () async {
      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      final export = await appState.exportPersonalData();

      expect(export.containsKey('meta'), isTrue);
      expect(export['meta']['legal_basis'], contains('152-ФЗ'));
      expect(export['meta']['document'], contains('персональных данных'));

      expect(export.containsKey('user'), isTrue);
      expect(export['user']['email'], isNotEmpty);

      expect(export.containsKey('profiles'), isTrue);
      expect(export['profiles'], isNotEmpty);

      expect(export.containsKey('medicine_boxes'), isTrue);
      expect(export['medicine_boxes'], isNotEmpty);

      expect(export.containsKey('medicines'), isTrue);
      expect(export.containsKey('notifications'), isTrue);
    });

    test('destroyAccount validates password and completely purges local data and session', () async {
      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);
      await apiService.setToken('mock_session_token');

      // User has token and is authenticated
      expect(await apiService.checkAuth(), isTrue);

      // Wrong password fails
      final fail = await appState.destroyAccount(currentPassword: 'wrong_pass');
      expect(fail['success'], isFalse);
      expect(fail['message'], contains('Неверный пароль'));

      // Correct password deletes data
      final success = await appState.destroyAccount(currentPassword: 'my_password');
      expect(success['success'], isTrue);
      expect(success['message'], contains('успешно удалены'));

      // Local user data purged
      expect(appState.currentUser, isNull);
      expect(appState.profiles.isEmpty, isTrue);
      expect(appState.boxes.isEmpty, isTrue);
      expect(appState.medicines.isEmpty, isTrue);
      expect(await apiService.checkAuth(), isFalse);
    });
  });

  group('2. SettingsScreen: 152-FZ UI Tiles and Modal Dialogs', () {
    testWidgets('Renders Change Password, Export DSAR, and Delete Account tiles', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(
        buildTestSettingsApp(appState: appState, apiService: apiService),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('settings_change_password_tile')), findsOneWidget);
      expect(find.text('Смена пароля (Argon2id)'), findsOneWidget);

      expect(find.byKey(const Key('settings_export_data_tile')), findsOneWidget);
      expect(find.text('Экспорт персональных данных (DSAR)'), findsOneWidget);

      expect(find.byKey(const Key('settings_delete_account_tile')), findsOneWidget);
      expect(find.text('Удаление учетной записи (ст. 21 152-ФЗ)'), findsOneWidget);
    });

    testWidgets('Change Password dialog: validation and successful update', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(
        buildTestSettingsApp(appState: appState, apiService: apiService),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Tap on change password tile
      await tester.tap(find.byKey(const Key('settings_change_password_tile')));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Смена пароля'), findsOneWidget);
      expect(find.textContaining('Хеширование Argon2id обеспечивает'), findsOneWidget);

      // Try empty submission -> validation errors
      await tester.tap(find.byKey(const Key('change_password_submit_btn')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Введите текущий пароль'), findsOneWidget);
      expect(find.text('Введите новый пароль'), findsOneWidget);

      // Enter short password (< 8 chars)
      await tester.enterText(find.byKey(const Key('change_password_current_input')), 'oldpass123');
      await tester.enterText(find.byKey(const Key('change_password_new_input')), 'short');
      await tester.enterText(find.byKey(const Key('change_password_confirm_input')), 'short');
      await tester.tap(find.byKey(const Key('change_password_submit_btn')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Минимум 8 символов'), findsOneWidget);

      // Enter matching passwords (>= 8 chars)
      await tester.enterText(find.byKey(const Key('change_password_new_input')), 'secureNewPass2026');
      await tester.enterText(find.byKey(const Key('change_password_confirm_input')), 'secureNewPass2026');
      await tester.tap(find.byKey(const Key('change_password_submit_btn')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 4)); // SnackBar dismiss

      // Dialog closed
      expect(find.byKey(const Key('change_password_submit_btn')), findsNothing);
    });

    testWidgets('Export Personal Data (DSAR) dialog: displays preview and metrics', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(
        buildTestSettingsApp(appState: appState, apiService: apiService),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Tap on export tile
      await tester.tap(find.byKey(const Key('settings_export_data_tile')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Выгрузка данных (152-ФЗ)'), findsOneWidget);
      expect(find.text('AES-256'), findsOneWidget);
      expect(find.text('Расшифровано'), findsOneWidget);
      expect(find.text('Скопировать JSON'), findsOneWidget);

      // Tap copy and close
      await tester.tap(find.text('Скопировать JSON'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Закрыть'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 4));

      expect(find.text('Выгрузка данных (152-ФЗ)'), findsNothing);
    });

    testWidgets('Delete Account dialog: confirms and navigates to LoginScreen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(
        buildTestSettingsApp(appState: appState, apiService: apiService),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Tap delete account tile
      await tester.tap(find.byKey(const Key('settings_delete_account_tile')));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Удаление аккаунта'), findsOneWidget);
      expect(find.textContaining('Право на забвение (ст. 21 152-ФЗ РФ)'), findsOneWidget);

      // Empty password check
      await tester.tap(find.byKey(const Key('delete_account_confirm_btn')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('delete_account_confirm_btn')), findsOneWidget);

      // Enter password and confirm
      await tester.enterText(find.byKey(const Key('delete_account_password_input')), 'validPassword123');
      await tester.tap(find.byKey(const Key('delete_account_confirm_btn')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 4)); // dismiss SnackBar

      // Should have navigated to LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
