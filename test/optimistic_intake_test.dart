import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/intake_log.dart';
import 'package:frontend/models/medicine.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/storage_service.dart';

class DelayedMockApiService extends ApiService {
  Completer<Map<String, dynamic>>? takeCompleter;
  Completer<Map<String, dynamic>>? undoCompleter;
  bool shouldFail = false;

  DelayedMockApiService(StorageService storageService)
      : super(baseUrl: 'http://localhost:8000', storageService: storageService, isMockMode: true);

  @override
  Future<Map<String, dynamic>> takeIntakeLog(
    int id, {
    bool confirmWithoutStock = false,
    String? idempotencyKey,
  }) async {
    if (shouldFail) {
      throw Exception('Network error 500');
    }
    if (takeCompleter != null) {
      return takeCompleter!.future;
    }
    return {'id': id, 'status': 'taken'};
  }

  @override
  Future<Map<String, dynamic>> undoIntakeLog(int id) async {
    if (shouldFail) {
      throw Exception('Network error 500');
    }
    if (undoCompleter != null) {
      return undoCompleter!.future;
    }
    return {'id': id, 'status': 'scheduled'};
  }
}

class TestOptimisticAppState extends AppState {
  TestOptimisticAppState(DelayedMockApiService apiService) : super(apiService: apiService);

  void setTestState({required List<IntakeLog> testIntakes, required List<Medicine> testMedicines}) {
    intakes.clear();
    intakes.addAll(testIntakes);
    medicines.clear();
    medicines.addAll(testMedicines);
    notifyListeners();
  }

  @override
  Future<void> refreshData() async {
    // В юнит-тесте сохраняем текущее локальное состояние
  }
}

void main() {
  late DelayedMockApiService mockApi;
  late TestOptimisticAppState appState;

  setUp(() async {
    final storage = await StorageService.init();
    mockApi = DelayedMockApiService(storage);
    appState = TestOptimisticAppState(mockApi);
  });

  group('DEF-54: Optimistic UI for take and undo intake', () {
    test('takeIntakeLog immediately marks intake as taken and decreases stock before network completes', () async {
      final initialMedicine = const Medicine(
        id: 1,
        boxId: 1,
        name: 'Аквадетрим',
        substance: 'Колекальциферол',
        form: 'Капли',
        remaining: 20.0,
        total: 20.0,
        expiry: '2027-01-01',
        status: 'ok',
      );

      final initialLog = const IntakeLog(
        id: 101,
        profileId: 1,
        medicineName: 'Аквадетрим',
        form: 'Капли',
        time: '09:00',
        rule: 'После еды',
        course: 'Витамин D',
        medicineId: 1,
        dosageQuantity: 2.0,
        status: 'scheduled',
        taken: false,
      );

      appState.setTestState(
        testIntakes: [initialLog],
        testMedicines: [initialMedicine],
      );

      mockApi.takeCompleter = Completer<Map<String, dynamic>>();

      // Запускаем асинхронный приём (сеть "зависла" в completer)
      final future = appState.takeIntakeLog(101);

      // Проверяем ДО завершения сетевого запроса: состояние обновилось оптимистично мгновенно (0 мс)!
      expect(appState.intakes.first.isTaken, isTrue);
      expect(appState.intakes.first.status, equals('taken'));
      expect(appState.medicines.first.remaining, equals(18.0));

      // Завершаем сетевой запрос
      mockApi.takeCompleter!.complete({'id': 101, 'status': 'taken'});
      await future;

      // После завершения состояние остаётся принятым
      expect(appState.intakes.first.isTaken, isTrue);
      expect(appState.medicines.first.remaining, equals(18.0));
    });

    test('takeIntakeLog rolls back state when network request fails', () async {
      final initialMedicine = const Medicine(
        id: 1,
        boxId: 1,
        name: 'Аквадетрим',
        substance: 'Колекальциферол',
        form: 'Капли',
        remaining: 20.0,
        total: 20.0,
        expiry: '2027-01-01',
        status: 'ok',
      );

      final initialLog = const IntakeLog(
        id: 101,
        profileId: 1,
        medicineName: 'Аквадетрим',
        form: 'Капли',
        time: '09:00',
        rule: 'После еды',
        course: 'Витамин D',
        medicineId: 1,
        dosageQuantity: 2.0,
        status: 'scheduled',
        taken: false,
      );

      appState.setTestState(
        testIntakes: [initialLog],
        testMedicines: [initialMedicine],
      );

      mockApi.shouldFail = true;

      // При ошибке сети метод пробрасывает ошибку, а локальное состояние откатывается назад
      await expectLater(appState.takeIntakeLog(101), throwsA(isA<Exception>()));

      // Локальное состояние обязано вернуться к исходному
      expect(appState.intakes.first.isTaken, isFalse);
      expect(appState.intakes.first.status, equals('scheduled'));
      expect(appState.medicines.first.remaining, equals(20.0));
    });

    test('undoIntake immediately marks intake as scheduled and restores stock before network completes', () async {
      final initialMedicine = const Medicine(
        id: 1,
        boxId: 1,
        name: 'Аквадетрим',
        substance: 'Колекальциферол',
        form: 'Капли',
        remaining: 18.0,
        total: 20.0,
        expiry: '2027-01-01',
        status: 'ok',
      );

      final initialLog = const IntakeLog(
        id: 101,
        profileId: 1,
        medicineName: 'Аквадетрим',
        form: 'Капли',
        time: '09:00',
        rule: 'После еды',
        course: 'Витамин D',
        medicineId: 1,
        dosageQuantity: 2.0,
        status: 'taken',
        taken: true,
      );

      appState.setTestState(
        testIntakes: [initialLog],
        testMedicines: [initialMedicine],
      );

      mockApi.undoCompleter = Completer<Map<String, dynamic>>();

      final future = appState.undoIntake(101);

      // Оптимистично статус сменился на scheduled, остаток восстановился
      expect(appState.intakes.first.isTaken, isFalse);
      expect(appState.intakes.first.status, equals('scheduled'));
      expect(appState.medicines.first.remaining, equals(20.0));

      mockApi.undoCompleter!.complete({'id': 101, 'status': 'scheduled'});
      await future;

      expect(appState.intakes.first.isTaken, isFalse);
      expect(appState.medicines.first.remaining, equals(20.0));
    });
  });
}
