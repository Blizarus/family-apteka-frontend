import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/storage_service.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/widgets/privacy_consent_dialog.dart';
import 'package:frontend/widgets/onboarding_guide_dialog.dart';
import 'package:frontend/screens/settings_screen.dart';

Widget createTestAppWithStorage({
  required StorageService storageService,
  Widget? child,
}) {
  final apiService = ApiService(
    isMockMode: true,
    storageService: storageService,
  );
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(apiService: apiService),
      ),
    ],
    child: MaterialApp(
      home: child ?? const Scaffold(body: Center(child: Text('Home'))),
    ),
  );
}

void main() {
  group('1. StorageService - 152-ФЗ Privacy & Onboarding Persistence (T-5)', () {
    test('default state has no consent and onboarding not completed', () async {
      final storage = StorageService();

      expect(await storage.isPrivacyConsentAccepted(), isFalse);
      expect(await storage.isPrivacyConsentCloudSync(), isFalse);
      expect(await storage.getPrivacyConsentDate(), isNull);
      expect(await storage.getPrivacyConsentVersion(), isNull);
      expect(await storage.isOnboardingCompleted(), isFalse);
    });

    test('savePrivacyConsent saves accepted status, cloudSync, version, and date', () async {
      final storage = StorageService();

      const testDate = '2026-11-01T20:00:00.000Z';
      await storage.savePrivacyConsent(
        accepted: true,
        cloudSync: true,
        version: 'v1.0-2026',
        date: testDate,
      );

      expect(await storage.isPrivacyConsentAccepted(), isTrue);
      expect(await storage.isPrivacyConsentCloudSync(), isTrue);
      expect(await storage.getPrivacyConsentVersion(), equals('v1.0-2026'));
      expect(await storage.getPrivacyConsentDate(), equals(testDate));
    });

    test('setOnboardingCompleted sets completed flag', () async {
      final storage = StorageService();

      expect(await storage.isOnboardingCompleted(), isFalse);
      await storage.setOnboardingCompleted(true);
      expect(await storage.isOnboardingCompleted(), isTrue);
      await storage.setOnboardingCompleted(false);
      expect(await storage.isOnboardingCompleted(), isFalse);
    });

    test('resetPrivacyConsent clears all privacy & onboarding keys', () async {
      final storage = StorageService();

      await storage.savePrivacyConsent(
        accepted: true,
        cloudSync: true,
        version: 'v1.0-2026',
      );
      await storage.setOnboardingCompleted(true);

      expect(await storage.isPrivacyConsentAccepted(), isTrue);
      expect(await storage.isOnboardingCompleted(), isTrue);

      await storage.resetPrivacyConsent();

      expect(await storage.isPrivacyConsentAccepted(), isFalse);
      expect(await storage.isPrivacyConsentCloudSync(), isFalse);
      expect(await storage.getPrivacyConsentDate(), isNull);
      expect(await storage.getPrivacyConsentVersion(), isNull);
      expect(await storage.isOnboardingCompleted(), isFalse);
    });
  });

  group('2. PrivacyConsentDialog Widget Tests', () {
    testWidgets('renders header, 152-FZ reference, and security bullets', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();

      await tester.pumpWidget(
        createTestAppWithStorage(
          storageService: storage,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => PrivacyConsentDialog.show(ctx, storageService: storage),
              child: const Text('Open Consent'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Consent'));
      await tester.pumpAndSettle();

      // Header and legal notices
      expect(find.text('Согласие на обработку ПДн'), findsOneWidget);
      expect(find.text('152-ФЗ РФ · Медицинские категории'), findsOneWidget);
      expect(find.text('Меры защиты и правовые основания'), findsOneWidget);
      expect(find.textContaining('ст. 10 152-ФЗ'), findsOneWidget);

      // Expand legal section
      await tester.tap(find.text('Меры защиты и правовые основания'));
      await tester.pumpAndSettle();

      expect(find.textContaining('AES-256 GCM', findRichText: true), findsOneWidget);
      expect(find.textContaining('Argon2id', findRichText: true), findsOneWidget);
      expect(find.textContaining('ст. 18 152-ФЗ', findRichText: true), findsOneWidget);

      // Checkboxes
      expect(find.byKey(const Key('privacy_mandatory_checkbox')), findsOneWidget);
      expect(find.byKey(const Key('privacy_cloud_checkbox')), findsOneWidget);

      // Accept button is disabled initially
      final acceptButtonFinder = find.byKey(const Key('privacy_accept_button'));
      expect(acceptButtonFinder, findsOneWidget);
      final ElevatedButton button = tester.widget(acceptButtonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('mandatory checkbox validates and enables accept button, persists consent', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();

      await tester.pumpWidget(
        createTestAppWithStorage(
          storageService: storage,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => PrivacyConsentDialog.show(ctx, storageService: storage),
              child: const Text('Open Consent'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Consent'));
      await tester.pumpAndSettle();

      // Check mandatory checkbox
      await tester.tap(find.byKey(const Key('privacy_mandatory_checkbox')));
      await tester.pumpAndSettle();

      // Verify button is now enabled
      final ElevatedButton buttonEnabled = tester.widget(find.byKey(const Key('privacy_accept_button')));
      expect(buttonEnabled.onPressed, isNotNull);

      // Tap accept button
      await tester.ensureVisible(find.byKey(const Key('privacy_accept_button')));
      await tester.tap(find.byKey(const Key('privacy_accept_button')));
      await tester.pumpAndSettle();

      // Dialog is closed
      expect(find.text('Согласие на обработку ПДн'), findsNothing);

      // Storage has consent saved
      expect(await storage.isPrivacyConsentAccepted(), isTrue);
      expect(await storage.isPrivacyConsentCloudSync(), isTrue);
      expect(await storage.getPrivacyConsentVersion(), equals('v1.0-2026'));
      expect(await storage.getPrivacyConsentDate(), isNotNull);
    });

    testWidgets('cloud sync optional checkbox can be toggled', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();

      await tester.pumpWidget(
        createTestAppWithStorage(
          storageService: storage,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => PrivacyConsentDialog.show(
                ctx,
                storageService: storage,
                initialCloudSync: true,
              ),
              child: const Text('Open Consent'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Consent'));
      await tester.pumpAndSettle();

      // Uncheck cloud sync
      await tester.tap(find.byKey(const Key('privacy_cloud_checkbox')));
      await tester.pumpAndSettle();

      // Check mandatory checkbox
      await tester.tap(find.byKey(const Key('privacy_mandatory_checkbox')));
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.byKey(const Key('privacy_accept_button')));
      await tester.tap(find.byKey(const Key('privacy_accept_button')));
      await tester.pumpAndSettle();

      // Storage has consent accepted, but cloud sync is false
      expect(await storage.isPrivacyConsentAccepted(), isTrue);
      expect(await storage.isPrivacyConsentCloudSync(), isFalse);
    });

    testWidgets('cancel button dismisses dialog without saving consent', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();

      await tester.pumpWidget(
        createTestAppWithStorage(
          storageService: storage,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => PrivacyConsentDialog.show(ctx, storageService: storage),
              child: const Text('Open Consent'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Consent'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('privacy_cancel_button')));
      await tester.tap(find.byKey(const Key('privacy_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.text('Согласие на обработку ПДн'), findsNothing);
      expect(await storage.isPrivacyConsentAccepted(), isFalse);
    });
  });

  group('3. OnboardingGuideDialog Widget Tests', () {
    testWidgets('walkthrough 3 cards: Security 152-FZ -> FEFO-Opened -> CDS Engine and finish', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();

      await tester.pumpWidget(
        createTestAppWithStorage(
          storageService: storage,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => OnboardingGuideDialog.show(ctx, storageService: storage),
              child: const Text('Open Onboarding'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Onboarding'));
      await tester.pumpAndSettle();

      // Slide 1: Security & 152-FZ
      expect(find.text('Защищенное хранение данных семьи'), findsOneWidget);
      expect(find.text('152-ФЗ РФ · AES-256 · Argon2id'), findsOneWidget);
      expect(find.byKey(const Key('onboarding_skip_button')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_next_button')), findsOneWidget);

      // Advance to Slide 2: FEFO-Opened
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Умный контроль сроков годности и вскрытых упаковок'), findsOneWidget);
      expect(find.text('FEFO-Opened · Контроль вскрытия'), findsOneWidget);

      // Advance to Slide 3: CDS Engine
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Контроль совместимости и аллергий'), findsOneWidget);
      expect(find.text('CDS-движок · ГРЛС Минздрава'), findsOneWidget);
      expect(find.byKey(const Key('onboarding_finish_button')), findsOneWidget);

      // Finish onboarding
      await tester.tap(find.byKey(const Key('onboarding_finish_button')));
      await tester.pumpAndSettle();

      // Dialog is dismissed and storage is updated
      expect(find.text('Контроль совместимости и аллергий'), findsNothing);
      expect(await storage.isOnboardingCompleted(), isTrue);
    });

    testWidgets('skip button completes onboarding immediately', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();

      await tester.pumpWidget(
        createTestAppWithStorage(
          storageService: storage,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => OnboardingGuideDialog.show(ctx, storageService: storage),
              child: const Text('Open Onboarding'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Onboarding'));
      await tester.pumpAndSettle();

      expect(find.text('Защищенное хранение данных семьи'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding_skip_button')));
      await tester.pumpAndSettle();

      expect(find.text('Защищенное хранение данных семьи'), findsNothing);
      expect(await storage.isOnboardingCompleted(), isTrue);
    });
  });

  group('4. SettingsScreen Integration Tests (152-FZ & Onboarding)', () {
    testWidgets('SettingsScreen displays 152-FZ consent status and opens dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();

      await tester.pumpWidget(
        createTestAppWithStorage(
          storageService: storage,
          child: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to 152-FZ section
      await tester.scrollUntilVisible(
        find.text('КОНФИДЕНЦИАЛЬНОСТЬ И БЕЗОПАСНОСТЬ (152-ФЗ)'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('КОНФИДЕНЦИАЛЬНОСТЬ И БЕЗОПАСНОСТЬ (152-ФЗ)'), findsOneWidget);
      expect(find.text('Шифрование AES-256 / Argon2id'), findsOneWidget);
      expect(find.text('Согласие на обработку данных (152-ФЗ)'), findsOneWidget);
      expect(find.text('Требуется подтверждение согласия'), findsOneWidget);
      expect(find.text('Гид по функциям (Онбординг)'), findsOneWidget);

      // Tap on consent tile to open dialog
      await tester.tap(find.byKey(const Key('settings_privacy_consent_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Согласие на обработку ПДн'), findsOneWidget);

      // Check mandatory and accept
      await tester.tap(find.byKey(const Key('privacy_mandatory_checkbox')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('privacy_accept_button')));
      await tester.pumpAndSettle();

      // Verified updated status in Settings
      expect(find.textContaining('Принято: редакция v1.0-2026'), findsOneWidget);
      expect(await storage.isPrivacyConsentAccepted(), isTrue);
    });

    testWidgets('SettingsScreen opens OnboardingGuideDialog from tile', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();

      await tester.pumpWidget(
        createTestAppWithStorage(
          storageService: storage,
          child: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('settings_onboarding_tile')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings_onboarding_tile')));
      await tester.pumpAndSettle();

      // Onboarding dialog is visible
      expect(find.text('Защищенное хранение данных семьи'), findsOneWidget);

      // Can skip
      await tester.tap(find.byKey(const Key('onboarding_skip_button')));
      await tester.pumpAndSettle();

      expect(find.text('Защищенное хранение данных семьи'), findsNothing);
      expect(await storage.isOnboardingCompleted(), isTrue);
    });
  });
}
