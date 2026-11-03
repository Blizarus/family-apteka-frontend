import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/today_screen.dart';
import 'package:frontend/screens/medicine_box_screen.dart';
import 'package:frontend/screens/notes_screen.dart';
import 'package:frontend/screens/family_screen.dart';
import 'package:frontend/screens/shopping_list_screen.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/screens/admin_panel_screen.dart';

Future<void> loadAppFonts() async {
  try {
    final regular = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
    final loaderRegular = FontLoader('Roboto');
    loaderRegular.addFont(Future.value(ByteData.view(regular.buffer)));
    await loaderRegular.load();

    final bold = File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync();
    final loaderBold = FontLoader('Roboto');
    loaderBold.addFont(Future.value(ByteData.view(bold.buffer)));
    await loaderBold.load();
  } catch (_) {}
}

Widget createScreenHarness({
  required Widget screen,
  required ThemeData theme,
  required AppState appState,
  required ApiService apiService,
}) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: screen,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
  });

  group('Golden Tests for Screens in Light and Dark Themes (Part B)', () {
    late ApiService apiService;
    late AppState appState;

    setUp(() async {
      apiService = ApiService(isMockMode: true);
      appState = AppState(apiService: apiService);
      await appState.loadInitialData();
    });

    final screens = <String, Widget Function()>{
      'login': () => const LoginScreen(),
      'today': () => const TodayScreen(),
      'medicine_box': () => const MedicineBoxScreen(),
      'notes': () => const NotesScreen(),
      'family': () => const FamilyScreen(),
      'shopping_list': () => const ShoppingListScreen(),
      'settings': () => const SettingsScreen(),
      'admin_panel': () => const AdminPanelScreen(),
    };

    for (final entry in screens.entries) {
      final name = entry.key;
      final builder = entry.value;

      testWidgets('Golden: $name screen (Light Theme)', (tester) async {
        tester.view.physicalSize = const Size(400, 850);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createScreenHarness(
            screen: builder(),
            theme: AppTheme.lightTheme,
            appState: appState,
            apiService: apiService,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${name}_light.png'),
        );
      });

      testWidgets('Golden: $name screen (Dark Theme)', (tester) async {
        tester.view.physicalSize = const Size(400, 850);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createScreenHarness(
            screen: builder(),
            theme: AppTheme.darkTheme,
            appState: appState,
            apiService: apiService,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${name}_dark.png'),
        );
      });
    }
  });
}
