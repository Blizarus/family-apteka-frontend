import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/main.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/storage_service.dart';
import 'package:frontend/theme/app_theme.dart';

Widget createSettingsTestApp({
  required ApiService apiService,
  required AppState appState,
}) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: appState.themeMode,
      home: const SettingsScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. AppState Theme Mode & StorageService Persistence', () {
    test('Default theme mode is ThemeMode.system', () {
      final storage = StorageService();
      final apiService = ApiService(isMockMode: true, storageService: storage);
      final appState = AppState(apiService: apiService);

      expect(appState.themeMode, ThemeMode.system);
    });

    test('setThemeMode updates themeMode, notifies listeners, and persists to StorageService', () async {
      final storage = StorageService();
      final apiService = ApiService(isMockMode: true, storageService: storage);
      final appState = AppState(apiService: apiService);

      int notifyCount = 0;
      appState.addListener(() => notifyCount++);

      // Switch to Dark
      appState.setThemeMode(ThemeMode.dark);
      expect(appState.themeMode, ThemeMode.dark);
      expect(notifyCount, 1);
      expect(await storage.getThemeMode(), 'dark');

      // Switch to Light
      appState.setThemeMode(ThemeMode.light);
      expect(appState.themeMode, ThemeMode.light);
      expect(notifyCount, 2);
      expect(await storage.getThemeMode(), 'light');

      // Switch to System
      appState.setThemeMode(ThemeMode.system);
      expect(appState.themeMode, ThemeMode.system);
      expect(notifyCount, 3);
      expect(await storage.getThemeMode(), 'system');

      // Calling with same mode does not notify redundantly
      appState.setThemeMode(ThemeMode.system);
      expect(notifyCount, 3);
    });

    test('AppState initializes and restores pre-saved dark theme from StorageService', () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'dark',
      });
      final storage = await StorageService.init();
      final apiService = ApiService(isMockMode: true, storageService: storage);
      final appState = AppState(apiService: apiService);

      await appState.loadThemeMode();
      expect(appState.themeMode, ThemeMode.dark);
    });

    test('AppState initializes and restores pre-saved light theme from StorageService', () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'light',
      });
      final storage = await StorageService.init();
      final apiService = ApiService(isMockMode: true, storageService: storage);
      final appState = AppState(apiService: apiService);

      await appState.loadThemeMode();
      expect(appState.themeMode, ThemeMode.light);
    });

    test('StorageService persists and reads theme_mode with fallback support', () async {
      final storage = StorageService();
      expect(await storage.getThemeMode(), isNull);

      await storage.saveThemeMode('dark');
      expect(await storage.getThemeMode(), 'dark');

      await storage.saveThemeMode('light');
      expect(await storage.getThemeMode(), 'light');

      await storage.saveThemeMode('system');
      expect(await storage.getThemeMode(), 'system');
    });
  });

  group('2. AppTheme.darkTheme & AppDarkColors Specifications', () {
    test('AppTheme.darkTheme has dark brightness and correct theme colors', () {
      final darkTheme = AppTheme.darkTheme;

      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, AppDarkColors.background);
      expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF0F172A));
      expect(darkTheme.colorScheme.primary, AppDarkColors.primary);
      expect(darkTheme.colorScheme.primary, const Color(0xFF14B8A6));
      expect(darkTheme.colorScheme.surface, AppDarkColors.surface);
      expect(darkTheme.colorScheme.surface, const Color(0xFF1E293B));
      expect(darkTheme.useMaterial3, isTrue);
    });

    test('AppDarkColors constants match design requirements', () {
      expect(AppDarkColors.background, const Color(0xFF0F172A));
      expect(AppDarkColors.surface, const Color(0xFF1E293B));
      expect(AppDarkColors.border, const Color(0xFF334155));
      expect(AppDarkColors.primary, const Color(0xFF14B8A6));
      expect(AppDarkColors.textPrimary, const Color(0xFFF8FAFC));
      expect(AppDarkColors.textSecondary, const Color(0xFF94A3B8));
      expect(AppDarkColors.textMuted, const Color(0xFF64748B));

      // Traffic light status colors
      expect(AppDarkColors.statusOkBg, const Color(0xFF064E3B));
      expect(AppDarkColors.statusOkText, const Color(0xFF6EE7B7));
      expect(AppDarkColors.statusExpiringBg, const Color(0xFF451A03));
      expect(AppDarkColors.statusExpiringText, const Color(0xFFFDE68A));
      expect(AppDarkColors.statusExpiredBg, const Color(0xFF4C0519));
      expect(AppDarkColors.statusExpiredText, const Color(0xFFFECDD3));
    });

    test('Custom dark theme component styles are properly configured', () {
      final darkTheme = AppTheme.darkTheme;

      // CardTheme
      expect(darkTheme.cardTheme.color, AppDarkColors.surface);
      expect(darkTheme.cardTheme.elevation, 0);

      // AppBarTheme
      expect(darkTheme.appBarTheme.backgroundColor, AppDarkColors.surface);
      expect(darkTheme.appBarTheme.iconTheme?.color, AppDarkColors.textPrimary);

      // TextTheme
      expect(darkTheme.textTheme.headlineMedium?.color, AppDarkColors.textPrimary);
      expect(darkTheme.textTheme.titleLarge?.color, AppDarkColors.textPrimary);
      expect(darkTheme.textTheme.bodyMedium?.color, AppDarkColors.textSecondary);
      expect(darkTheme.textTheme.bodySmall?.color, AppDarkColors.textMuted);

      // InputDecorationTheme
      expect(darkTheme.inputDecorationTheme.filled, isTrue);
      expect(darkTheme.inputDecorationTheme.fillColor, AppDarkColors.surface);

      // ElevatedButtonTheme
      final btnStyle = darkTheme.elevatedButtonTheme.style;
      expect(btnStyle, isNotNull);

      // DialogTheme
      expect(darkTheme.dialogTheme.backgroundColor, AppDarkColors.surface);

      // DividerTheme
      expect(darkTheme.dividerTheme.color, AppDarkColors.border);
    });

    test('AppTheme.lightTheme retains light mode specifications', () {
      final lightTheme = AppTheme.lightTheme;

      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, AppColors.background);
      expect(lightTheme.colorScheme.primary, AppColors.primary);
      expect(lightTheme.colorScheme.surface, AppColors.surface);
    });
  });

  group('3. SettingsScreen Theme Switcher UI & Interaction', () {
    testWidgets('SettingsScreen displays theme switcher section and segments', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();
      final apiService = ApiService(isMockMode: true, storageService: storage);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(
        createSettingsTestApp(apiService: apiService, appState: appState),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Verify Section Header
      expect(find.text('ТЕМА ОФОРМЛЕНИЯ'), findsOneWidget);
      expect(find.text('Тема оформления'), findsOneWidget);
      expect(find.text('Выбор светлой, тёмной или системной темы'), findsOneWidget);

      // Verify SegmentedButton
      final segmentedButtonFinder = find.byKey(const Key('theme_mode_segmented_button'));
      expect(segmentedButtonFinder, findsOneWidget);

      // Verify Segment options
      expect(find.text('Системная 🌓'), findsOneWidget);
      expect(find.text('Светлая ☀️'), findsOneWidget);
      expect(find.text('Тёмная 🌙'), findsOneWidget);
    });

    testWidgets('Tapping segments in SettingsScreen toggles themeMode in AppState', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();
      final apiService = ApiService(isMockMode: true, storageService: storage);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(
        createSettingsTestApp(apiService: apiService, appState: appState),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(appState.themeMode, ThemeMode.system);

      // Tap Dark
      final darkSegment = find.text('Тёмная 🌙');
      await tester.ensureVisible(darkSegment);
      await tester.tap(darkSegment);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(appState.themeMode, ThemeMode.dark);
      expect(await storage.getThemeMode(), 'dark');

      // Tap Light
      final lightSegment = find.text('Светлая ☀️');
      await tester.ensureVisible(lightSegment);
      await tester.tap(lightSegment);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(appState.themeMode, ThemeMode.light);
      expect(await storage.getThemeMode(), 'light');

      // Tap System
      final systemSegment = find.text('Системная 🌓');
      await tester.ensureVisible(systemSegment);
      await tester.tap(systemSegment);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(appState.themeMode, ThemeMode.system);
      expect(await storage.getThemeMode(), 'system');
    });

    testWidgets('FamilyAptekaApp applies darkTheme when AppState.themeMode is ThemeMode.dark', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = StorageService();
      final apiService = ApiService(isMockMode: true, storageService: storage);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: apiService),
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: const FamilyAptekaApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // By default system mode
      expect(appState.themeMode, ThemeMode.system);

      // Switch to Dark mode
      appState.setThemeMode(ThemeMode.dark);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Check MaterialApp theme resolution
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.dark);
      expect(materialApp.theme, AppTheme.lightTheme);
      expect(materialApp.darkTheme, AppTheme.darkTheme);
    });
  });
}
