import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:dio/dio.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/services/api_service.dart';

import 'package:frontend/services/storage_service.dart';

import 'package:frontend/providers/app_state.dart';

import 'package:frontend/theme/app_theme.dart';

import 'package:frontend/screens/medicine_box_screen.dart';

import 'package:frontend/screens/today_screen.dart';

import 'package:frontend/screens/home_screen.dart';

import 'package:frontend/widgets/barcode_scanner_sheet.dart';

import 'package:provider/provider.dart';



void main() {

  TestWidgetsFlutterBinding.ensureInitialized();



  setUp(() {

    SharedPreferences.setMockInitialValues({});

  });



  group('Session Retention & Resilient Auth Tests', () {

    test('Token is retained in secure storage and in-memory cache', () async {

      FlutterSecureStorage.setMockInitialValues({});

      final storage = await StorageService.init();

      final apiService = ApiService(

        isMockMode: false,

        storageService: storage,

        secureStorage: const FlutterSecureStorage(),

      );



      // Save token

      await apiService.setToken('test_persisted_sanctum_token');



      // Verify token is available via secureStorage

      expect(await const FlutterSecureStorage().read(key: 'auth_token'), 'test_persisted_sanctum_token');

      expect(apiService.token, 'test_persisted_sanctum_token');

    });



    test('checkAuth retains user login when network throws connection timeout (offline resilience)', () async {

      FlutterSecureStorage.setMockInitialValues({'auth_token': 'valid_token_xyz'});

      final storage = await StorageService.init();



      final dio = Dio();

      dio.interceptors.add(

        InterceptorsWrapper(

          onRequest: (options, handler) {

            if (options.path.contains('/auth/me')) {

              return handler.reject(

                DioException(

                  requestOptions: options,

                  type: DioExceptionType.connectionTimeout,

                  error: 'Network connection timeout',

                ),

              );

            }

            return handler.next(options);

          },

        ),

      );



      final apiService = ApiService(

        dio: dio,

        isMockMode: false,

        storageService: storage,

        secureStorage: const FlutterSecureStorage(),

      );



      // Pre-set token in memory/storage

      await apiService.setToken('valid_token_xyz');



      final isAuth = await apiService.checkAuth();

      // Should remain true (not kicked out to login screen due to temporary connection timeout)

      expect(isAuth, isTrue);

      expect(apiService.token, 'valid_token_xyz');

    });



    test('checkAuth clears token and returns false only when server explicitly returns 401 Unauthorized', () async {

      FlutterSecureStorage.setMockInitialValues({'auth_token': 'revoked_token'});

      final storage = await StorageService.init();



      final dio = Dio();

      dio.interceptors.add(

        InterceptorsWrapper(

          onRequest: (options, handler) {

            if (options.path.contains('/auth/me')) {

              return handler.reject(

                DioException(

                  requestOptions: options,

                  response: Response(

                    requestOptions: options,

                    statusCode: 401,

                    data: {'message': 'Unauthenticated.'},

                  ),

                ),

              );

            }

            return handler.next(options);

          },

        ),

      );



      final apiService = ApiService(

        dio: dio,

        isMockMode: false,

        storageService: storage,

        secureStorage: const FlutterSecureStorage(),

      );

      await apiService.setToken('revoked_token');



      final isAuth = await apiService.checkAuth();

      expect(isAuth, isFalse);

      expect(await const FlutterSecureStorage().read(key: 'auth_token'), isNull);

      expect(apiService.token, isNull);

    });

  });



  group('Dark Theme Screen Scaffolds & Input Adaptation', () {

    testWidgets('MedicineBoxScreen Scaffold inherits dark theme background instead of white', (tester) async {

      tester.view.physicalSize = const Size(800, 1200);

      tester.view.devicePixelRatio = 1.0;

      addTearDown(tester.view.resetPhysicalSize);



      final storage = await StorageService.init();

      final apiService = ApiService(isMockMode: true, storageService: storage);

      final appState = AppState(apiService: apiService);



      await tester.pumpWidget(

        MultiProvider(

          providers: [

            Provider<ApiService>.value(value: apiService),

            ChangeNotifierProvider<AppState>.value(value: appState),

          ],

          child: MaterialApp(

            theme: AppTheme.lightTheme,

            darkTheme: AppTheme.darkTheme,

            themeMode: ThemeMode.dark,

            home: const MedicineBoxScreen(),

          ),

        ),

      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 500));



      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);

      // In dark mode, Scaffold background must be AppDarkColors.background (Color(0xFF0F172A))

      // and NOT hardcoded to AppColors.background (white/light)

      expect(scaffold.backgroundColor, AppDarkColors.background);

    });



    testWidgets('TodayScreen Scaffold inherits dark theme background in dark mode', (tester) async {

      tester.view.physicalSize = const Size(800, 1200);

      tester.view.devicePixelRatio = 1.0;

      addTearDown(tester.view.resetPhysicalSize);



      final storage = await StorageService.init();

      final apiService = ApiService(isMockMode: true, storageService: storage);

      final appState = AppState(apiService: apiService);



      await tester.pumpWidget(

        MultiProvider(

          providers: [

            Provider<ApiService>.value(value: apiService),

            ChangeNotifierProvider<AppState>.value(value: appState),

          ],

          child: MaterialApp(

            theme: AppTheme.lightTheme,

            darkTheme: AppTheme.darkTheme,

            themeMode: ThemeMode.dark,

            home: const TodayScreen(),

          ),

        ),

      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 500));



      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);

      expect(scaffold.backgroundColor, AppDarkColors.background);

    });



    testWidgets('HomeScreen Scaffold inherits dark theme background in dark mode', (tester) async {

      tester.view.physicalSize = const Size(800, 1200);

      tester.view.devicePixelRatio = 1.0;

      addTearDown(tester.view.resetPhysicalSize);



      final storage = await StorageService.init();

      final apiService = ApiService(isMockMode: true, storageService: storage);

      final appState = AppState(apiService: apiService);



      await tester.pumpWidget(

        MultiProvider(

          providers: [

            Provider<ApiService>.value(value: apiService),

            ChangeNotifierProvider<AppState>.value(value: appState),

          ],

          child: MaterialApp(

            theme: AppTheme.lightTheme,

            darkTheme: AppTheme.darkTheme,

            themeMode: ThemeMode.dark,

            home: const HomeScreen(),

          ),

        ),

      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 500));



      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);

      expect(scaffold.backgroundColor, AppDarkColors.background);

    });

  });



  group('BarcodeScannerSheet Resilience Tests', () {

    testWidgets('BarcodeScannerSheet renders controls and returns manual or preset code', (tester) async {

      tester.view.physicalSize = const Size(800, 1200);

      tester.view.devicePixelRatio = 1.0;

      addTearDown(tester.view.resetPhysicalSize);



      String? detectedCode;



      await tester.pumpWidget(

        MaterialApp(

          theme: AppTheme.lightTheme,

          darkTheme: AppTheme.darkTheme,

          home: Scaffold(

            body: Builder(

              builder: (context) => ElevatedButton(

                onPressed: () async {

                  detectedCode = await BarcodeScannerSheet.show(context);

                },

                child: const Text('Open Scanner'),

              ),

            ),

          ),

        ),

      );



      // Open scanner modal

      await tester.tap(find.text('Open Scanner'));

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));



      // Preset button for Ibuprofen should be present

      expect(find.text('Тестовый штрихкод: Ибупрофен (4601234567890)'), findsOneWidget);



      // Tap preset

      await tester.tap(find.text('Тестовый штрихкод: Ибупрофен (4601234567890)'));

      await tester.pumpAndSettle();



      // Scanner dismissed and returned the code

      expect(detectedCode, '4601234567890');

    });

  });



}

