import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/providers/app_state.dart';

Widget buildTestLoginApp({bool? showDemoCredentials}) {
  final apiService = ApiService(isMockMode: true);
  final appState = AppState(apiService: apiService);

  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp(
      home: LoginScreen(showDemoCredentials: showDemoCredentials),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DEF-06: Sensitive credentials and demo buttons UI security tests', () {
    testWidgets('Demo credentials and quick login buttons are visible when enabled (Debug mode)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestLoginApp(showDemoCredentials: true));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Demo hints and credentials must be present in debug/demo mode
      expect(find.textContaining('Тестовые данные:'), findsOneWidget);
      expect(find.textContaining('admin123'), findsOneWidget);
      expect(find.text('Тестовый вход (anna@family.test)'), findsOneWidget);
      expect(find.text('Вход администратора (admin@family.test)'), findsOneWidget);
      expect(find.text('Войти в аккаунт'), findsOneWidget);
    });

    testWidgets('DEF-06: Demo credentials and admin passwords are NOT displayed in Release mode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestLoginApp(showDemoCredentials: false));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // In Release mode, hard-coded passwords and demo buttons must be completely absent (CWE-798, CWE-200)
      expect(find.textContaining('admin123'), findsNothing);
      expect(find.textContaining('Тестовые данные:'), findsNothing);
      expect(find.text('Тестовый вход (anna@family.test)'), findsNothing);
      expect(find.text('Вход администратора (admin@family.test)'), findsNothing);

      // Normal login form elements must remain intact
      expect(find.text('ЭЛЕКТРОННАЯ ПОЧТА'), findsOneWidget);
      expect(find.text('ПАРОЛЬ'), findsOneWidget);
      expect(find.text('Войти в аккаунт'), findsOneWidget);
    });
  });
}
