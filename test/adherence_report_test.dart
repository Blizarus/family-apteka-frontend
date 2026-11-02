import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/models/adherence_report.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/screens/history_report_screen.dart';
import 'package:frontend/screens/today_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/storage_service.dart';

Widget createTestApp({
  required Widget child,
  required ApiService apiService,
  AppState? appState,
}) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<AppState>.value(
        value: appState ?? AppState(apiService: apiService),
      ),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StorageService & Persistence Tests (T-4)', () {
    test('StorageService saves and retrieves baseUrl, profileId, and boxId', () async {
      final storage = await StorageService.init();

      expect(await storage.getBaseUrl(), isNull);
      await storage.saveBaseUrl('http://my-custom-server.swtest.ru/api');
      expect(await storage.getBaseUrl(), 'http://my-custom-server.swtest.ru/api');

      expect(await storage.getSelectedProfileId(), isNull);
      await storage.saveSelectedProfileId(2);
      expect(await storage.getSelectedProfileId(), 2);

      expect(await storage.getSelectedBoxId(), isNull);
      await storage.saveSelectedBoxId(5);
      expect(await storage.getSelectedBoxId(), 5);
    });

    test('AppState persists selectedBoxId and selectedProfileId to StorageService', () async {
      final storage = await StorageService.init();
      final apiService = ApiService(isMockMode: true, storageService: storage);
      final appState = AppState(apiService: apiService);

      appState.selectBox(3);
      expect(appState.selectedBoxId, 3);
      expect(await storage.getSelectedBoxId(), 3);

      appState.selectProfile(2);
      expect(appState.selectedProfileId, 2);
      expect(await storage.getSelectedProfileId(), 2);
    });
  });

  group('AdherenceReport Model & ApiService Tests (T-3)', () {
    test('AdherenceReport parses JSON correctly and evaluates compliance levels', () {
      final json = {
        'period': {
          'type': '7_days',
          'start_date': '2026-10-26',
          'end_date': '2026-11-01',
        },
        'scheduled_count': 14,
        'taken_count': 12,
        'missed_count': 2,
        'adherence_rate': 85.7,
        'streak_days': 4,
        'daily_stats': [
          {'date': '2026-10-26', 'scheduled': 2, 'taken': 2, 'missed': 0},
          {'date': '2026-10-27', 'scheduled': 2, 'taken': 1, 'missed': 1},
        ],
        'medicines_summary': [
          {
            'medicine_id': 1,
            'name': 'Аспирин Кардио',
            'scheduled_count': 7,
            'taken_count': 6,
            'missed_count': 1,
            'adherence_rate': 85.7,
          }
        ],
      };

      final report = AdherenceReport.fromJson(json);

      expect(report.period.type, '7_days');
      expect(report.scheduledCount, 14);
      expect(report.takenCount, 12);
      expect(report.missedCount, 2);
      expect(report.adherenceRate, 85.7);
      expect(report.streakDays, 4);
      expect(report.complianceLevelLabel, 'Высокий комплаенс');
      expect(report.dailyStats.length, 2);
      expect(report.medicinesSummary.first.name, 'Аспирин Кардио');

      // Test moderate and low compliance levels
      final modReport = AdherenceReport.fromJson({...json, 'adherence_rate': 65.0});
      expect(modReport.complianceLevelLabel, 'Умеренный комплаенс');

      final lowReport = AdherenceReport.fromJson({...json, 'adherence_rate': 45.0});
      expect(lowReport.complianceLevelLabel, 'Низкий комплаенс');
    });

    test('Adherence rate is dynamically calculated from actual intake counts', () {
      // 1. DailyStat dynamic adherence calculation from actual scheduled/taken counts
      final stat1 = DailyStat(date: '2026-11-01', scheduled: 4, taken: 3, missed: 1);
      expect(stat1.adherenceRate, equals(75.0)); // (3 / 4) * 100 = 75.0%

      final stat2 = DailyStat(date: '2026-11-02', scheduled: 5, taken: 4, missed: 1);
      expect(stat2.adherenceRate, equals(80.0)); // (4 / 5) * 100 = 80.0%

      final statEmpty = DailyStat(date: '2026-11-03', scheduled: 0, taken: 0, missed: 0);
      expect(statEmpty.adherenceRate, equals(100.0)); // 0 scheduled -> 100.0%

      // 2. MedicineAdherence verification
      final med = MedicineAdherence(
        medicineId: 10,
        name: 'Эналаприл',
        scheduledCount: 20,
        takenCount: 16,
        missedCount: 4,
        adherenceRate: 80.0,
      );
      expect((med.takenCount / med.scheduledCount) * 100, equals(med.adherenceRate));
    });

    test('ApiService.getAdherenceReport returns mock report for 7 and 30 days', () async {
      final apiService = ApiService(isMockMode: true);

      final report7 = await apiService.getAdherenceReport(period: '7_days');
      expect(report7.dailyStats.length, 7);
      expect(report7.adherenceRate, greaterThan(70));
      expect(report7.medicinesSummary, isNotEmpty);

      final report30 = await apiService.getAdherenceReport(period: '30_days');
      expect(report30.dailyStats.length, 30);
      expect(report30.period.type, '30_days');
    });
  });

  group('HistoryReportScreen Widget Tests (T-3 UI)', () {
    testWidgets('HistoryReportScreen renders KPI, chart, summary and handles period toggle', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(
        createTestApp(
          child: const HistoryReportScreen(),
          apiService: apiService,
          appState: appState,
        ),
      );

      // Advance time for loadInitialData and fetchAdherenceReport
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Screen Header
      expect(find.text('Отчёт для врача'), findsOneWidget);
      expect(find.text('Комплаенс и фармакотерапия'), findsOneWidget);

      // Verify Filter buttons
      expect(find.text('7 дней'), findsOneWidget);
      expect(find.text('30 дней'), findsOneWidget);

      // Verify Hero KPI Cards
      expect(find.textContaining('КОМПЛАЕНС'), findsWidgets);
      expect(find.text('Принято'), findsWidgets);
      expect(find.text('Пропущено'), findsOneWidget);
      expect(find.text('Серия дней'), findsOneWidget);

      // Verify Daily Chart
      expect(find.text('ПОСУТОЧНАЯ ДИНАМИКА ПРИЁМОВ'), findsOneWidget);

      // Verify Medicines Summary
      expect(find.text('ДИСЦИПЛИНА ПО ПРЕПАРАТАМ'), findsOneWidget);
      expect(find.text('Аспирин Кардио'), findsOneWidget);

      // Verify Doctor notes field and Export button
      expect(find.text('Распечатать отчёт для врача'), findsOneWidget);

      // Tap 30 days toggle
      await tester.tap(find.text('30 дней'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(appState.reportPeriod, '30_days');
    });

    testWidgets('TodayScreen: analytics icon opens HistoryReportScreen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiService = ApiService(isMockMode: true);
      final appState = AppState(apiService: apiService);

      await tester.pumpWidget(
        createTestApp(
          child: const TodayScreen(),
          apiService: apiService,
          appState: appState,
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Find analytics button with tooltip 'Отчёт для врача'
      final reportBtn = find.byTooltip('Отчёт для врача');
      expect(reportBtn, findsWidgets);

      await tester.tap(reportBtn.first);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify HistoryReportScreen opened
      expect(find.byType(HistoryReportScreen), findsOneWidget);
      expect(find.text('Отчёт для врача'), findsWidgets);
    });
  });
}
