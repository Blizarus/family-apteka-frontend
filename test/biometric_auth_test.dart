import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/storage_service.dart';
import 'package:frontend/services/biometric_service.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/widgets/biometric_prompt_dialog.dart';

Widget buildTestSettingsApp({
  required AppState appState,
  required ApiService apiService,
  BiometricService? biometricService,
}) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp(
      home: SettingsScreen(biometricService: biometricService),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. BiometricService & StorageService Unit Tests (T-14)', () {
    test('StorageService saves and retrieves biometricEnabled state', () async {
      final storage = StorageService();
      expect(await storage.isBiometricEnabled(), isFalse);

      await storage.setBiometricEnabled(true);
      expect(await storage.isBiometricEnabled(), isTrue);

      await storage.setBiometricEnabled(false);
      expect(await storage.isBiometricEnabled(), isFalse);
    });

    test('StorageService clearAllData resets biometricEnabled state', () async {
      final storage = StorageService();
      await storage.setBiometricEnabled(true);
      expect(await storage.isBiometricEnabled(), isTrue);

      await storage.clearAllData();
      expect(await storage.isBiometricEnabled(), isFalse);
    });

    test('BiometricService checks availability in mock mode', () async {
      final bioService = BiometricService(isMockMode: true);
      expect(await bioService.isBiometricAvailable(), isTrue);

      bioService.setMockAvailable(false);
      expect(await bioService.isBiometricAvailable(), isFalse);
    });

    test('BiometricService authenticate succeeds and fails according to mock result', () async {
      final bioService = BiometricService(isMockMode: true);
      expect(
        await bioService.authenticate(localizedReason: 'Test authentication'),
        isTrue,
      );

      bioService.setMockAuthResult(false);
      expect(
        await bioService.authenticate(localizedReason: 'Test authentication'),
        isFalse,
      );
    });

    test('BiometricService reads and writes biometric auth state via StorageService', () async {
      final storage = StorageService();
      final bioService = BiometricService(
        storageService: storage,
        isMockMode: true,
      );

      expect(await bioService.isBiometricAuthEnabled(), isFalse);
      expect(await bioService.isBiometricEnabled(), isFalse);

      await bioService.setBiometricAuthEnabled(true);
      expect(await bioService.isBiometricAuthEnabled(), isTrue);
      expect(await storage.isBiometricEnabled(), isTrue);

      await bioService.setBiometricEnabled(false);
      expect(await bioService.isBiometricAuthEnabled(), isFalse);
      expect(await storage.isBiometricEnabled(), isFalse);
    });
  });

  group('2. BiometricPromptDialog Widget Tests', () {
    testWidgets('Displays emerald fingerprint icon, title, reason, and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiometricPromptDialog(
              title: 'Вход по биометрии',
              localizedReason: 'Подтвердите личность для доступа',
            ),
          ),
        ),
      );

      expect(find.text('Вход по биометрии'), findsOneWidget);
      expect(find.text('Подтвердите личность для доступа'), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint_rounded), findsNWidgets(2)); // Circular container + button
      expect(find.byKey(const Key('biometric_confirm_button')), findsOneWidget);
      expect(find.byKey(const Key('biometric_password_fallback_button')), findsOneWidget);
    });

    testWidgets('Confirm button calls authenticate and pops true on success', (tester) async {
      bool? dialogResult;
      final bioService = BiometricService(isMockMode: true, mockAuthResult: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await BiometricPromptDialog.show(
                    context,
                    biometricService: bioService,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('biometric_confirm_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('biometric_confirm_button')));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
      expect(find.byType(BiometricPromptDialog), findsNothing);
    });

    testWidgets('Confirm button displays error banner when authentication fails', (tester) async {
      final bioService = BiometricService(isMockMode: true, mockAuthResult: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiometricPromptDialog(
              biometricService: bioService,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('biometric_error_banner')), findsNothing);

      await tester.tap(find.byKey(const Key('biometric_confirm_button')));
      await tester.pump();

      expect(find.byKey(const Key('biometric_error_banner')), findsOneWidget);
      expect(find.textContaining('Отпечаток не распознан'), findsOneWidget);
    });

    testWidgets('Password fallback button invokes callback and pops false', (tester) async {
      bool? dialogResult;
      bool passwordFallbackInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await BiometricPromptDialog.show(
                    context,
                    onPasswordFallback: () {
                      passwordFallbackInvoked = true;
                    },
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('biometric_password_fallback_button')));
      await tester.pumpAndSettle();

      expect(dialogResult, isFalse);
      expect(passwordFallbackInvoked, isTrue);
      expect(find.byType(BiometricPromptDialog), findsNothing);
    });
  });

  group('3. SettingsScreen Biometric Switch UI Integration Tests (T-14)', () {
    testWidgets('Displays biometric switch in 152-FZ section with fingerprint icon and labels', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();
      final apiService = ApiService(isMockMode: true, storageService: storage);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(buildTestSettingsApp(
        appState: appState,
        apiService: apiService,
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final switchFinder = find.byKey(const Key('settings_biometric_switch'));
      expect(switchFinder, findsOneWidget);

      expect(find.text('Биометрическая защита (Touch ID / Face ID)'), findsOneWidget);
      expect(find.text('Быстрая аутентификация при разблокировке приложения'), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);

      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isFalse);
    });

    testWidgets('SwitchListTile loads enabled state if already saved in storage', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();
      await storage.setBiometricEnabled(true);

      final apiService = ApiService(isMockMode: true, storageService: storage);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(buildTestSettingsApp(
        appState: appState,
        apiService: apiService,
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final switchFinder = find.byKey(const Key('settings_biometric_switch'));
      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('Toggling switch on prompts biometric verification and turns on on success', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();
      final bioService = BiometricService(
        storageService: storage,
        isMockMode: true,
        mockAuthResult: true,
      );
      final apiService = ApiService(
        isMockMode: true,
        storageService: storage,
        biometricService: bioService,
      );
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(buildTestSettingsApp(
        appState: appState,
        apiService: apiService,
        biometricService: bioService,
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final switchFinder = find.byKey(const Key('settings_biometric_switch'));
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

      // Tap switch to turn on
      await tester.tap(switchFinder);
      await tester.pump(const Duration(milliseconds: 500));

      // Should be turned on and persisted
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
      expect(await storage.isBiometricEnabled(), isTrue);
      expect(find.text('Биометрическая защита включена'), findsOneWidget);

      // Clean snackbar
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Toggling switch on when biometric fails shows warning toast and stays off', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();
      final bioService = BiometricService(
        storageService: storage,
        isMockMode: true,
        mockAuthResult: false, // Emulate failure
      );
      final apiService = ApiService(
        isMockMode: true,
        storageService: storage,
        biometricService: bioService,
      );
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(buildTestSettingsApp(
        appState: appState,
        apiService: apiService,
        biometricService: bioService,
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final switchFinder = find.byKey(const Key('settings_biometric_switch'));
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

      // Tap switch to turn on
      await tester.tap(switchFinder);
      await tester.pump(const Duration(milliseconds: 500));

      // Should remain off and show failure warning toast
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
      expect(await storage.isBiometricEnabled(), isFalse);
      expect(find.text('Не удалось подтвердить биометрию'), findsOneWidget);

      // Clean snackbar
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Toggling switch off disables biometric and updates storage', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();
      await storage.setBiometricEnabled(true);

      final bioService = BiometricService(
        storageService: storage,
        isMockMode: true,
        mockAuthResult: true,
      );
      final apiService = ApiService(
        isMockMode: true,
        storageService: storage,
        biometricService: bioService,
      );
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(buildTestSettingsApp(
        appState: appState,
        apiService: apiService,
        biometricService: bioService,
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final switchFinder = find.byKey(const Key('settings_biometric_switch'));
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

      // Tap switch to turn off
      await tester.tap(switchFinder);
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
      expect(await storage.isBiometricEnabled(), isFalse);
      expect(find.text('Биометрическая защита отключена'), findsOneWidget);

      // Clean snackbar
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
