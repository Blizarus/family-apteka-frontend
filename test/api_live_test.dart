import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/services/api_service.dart';

const bool isLiveApiTest = bool.fromEnvironment('LIVE_API_TEST', defaultValue: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live Laravel API Integration Test', () {
    late ApiService apiService;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      apiService = ApiService(
        isMockMode: false,
        baseUrl: const String.fromEnvironment('STAGING_API_URL', defaultValue: 'http://127.0.0.1:8000/api'),
        secureStorage: const FlutterSecureStorage(),
      );
    });

    test(
      'Real login with anna@family.test succeeds and returns Sanctum token',
      () async {
        try {
          final res = await apiService.login('anna@family.test', 'password');
          expect(res['token'], isNotNull);
          expect(res['token_type'], 'Bearer');
          expect(res['user']['email'], 'anna@family.test');

          // Check auth status
          final isAuth = await apiService.checkAuth();
          expect(isAuth, isTrue);

          // Fetch Profiles
          final profiles = await apiService.getProfiles();
          expect(profiles, isNotEmpty);
          expect(profiles.any((p) => p.name.contains('Анна')), isTrue);

          // Fetch Medicine Boxes
          final boxes = await apiService.getMedicineBoxes();
          expect(boxes, isNotEmpty);
          expect(boxes.any((b) => b.name.contains('Домашняя')), isTrue);

          // Fetch Medicines
          final medicines = await apiService.getMedicines();
          expect(medicines, isNotEmpty);

          // Fetch Intakes (using today's date)
          final todayStr = DateTime.now().toIso8601String().substring(0, 10);
          final intakes = await apiService.getIntakes(date: todayStr);
          expect(intakes, isA<List>());

          // Search Reference Medicines Catalog
          final refMeds = await apiService.searchReferenceMedicines('Ибупрофен');
          expect(refMeds, isNotEmpty);
          expect(refMeds.first.tradeName, contains('Ибупрофен'));

          // Test CDS Medication Safety Check
          final safety = await apiService.checkMedicationSafety(
            profileId: profiles.first.id,
            referenceMedicineId: refMeds.first.id,
          );
          expect(safety, contains('is_safe'));
        } on DioException catch (e) {
          fail('Отказ интеграции с живым API [${e.requestOptions.uri}]: ${e.message}');
        }
      },
      skip: !isLiveApiTest
          ? 'Пропущено: для запуска с реальным API укажите --dart-define=LIVE_API_TEST=true'
          : null,
    );

    test(
      'Wrong password returns 401 Unauthorized or 429 Rate Limiting',
      () async {
        try {
          await apiService.login('anna@family.test', 'wrong_pass');
          fail('Should throw DioException with 401 or 429');
        } on DioException catch (e) {
          if (e.response == null) {
            fail('Отказ интеграции с живым API [${e.requestOptions.uri}]: ${e.message}');
          }
          expect([401, 429], contains(e.response?.statusCode));
        }
      },
      skip: !isLiveApiTest
          ? 'Пропущено: для запуска с реальным API укажите --dart-define=LIVE_API_TEST=true'
          : null,
    );
  });
}
