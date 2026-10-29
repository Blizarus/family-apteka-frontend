import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/api_service.dart';

void main() {
  group('Live Laravel API Integration Test', () {
    late ApiService apiService;

    setUp(() {
      apiService = ApiService(
        isMockMode: false,
        baseUrl: 'http://127.0.0.1:8000/api',
      );
    });

    test('Real login with anna@family.test succeeds and returns Sanctum token', () async {
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

      // Fetch Intakes (using the date from database: 2026-10-28)
      final intakes = await apiService.getIntakes(date: '2026-10-28');
      expect(intakes, isNotEmpty);

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
    });

    test('Wrong password returns 401 Unauthorized or 429 Rate Limiting', () async {
      try {
        await apiService.login('anna@family.test', 'wrong_pass');
        fail('Should throw DioException with 401 or 429');
      } on DioException catch (e) {
        expect([401, 429], contains(e.response?.statusCode));
      }
    });
  });
}
