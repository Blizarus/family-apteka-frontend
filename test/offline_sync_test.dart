import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DEF-41: Offline Sync & Caching Verification', () {
    late StorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'test_token'});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
    });

    test('syncOfflineDatabase returns false on network error instead of fake true', () async {
      final mockDio = Dio(BaseOptions(baseUrl: 'http://localhost/api'));
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Network unreachable',
                type: DioExceptionType.connectionError,
              ),
            );
          },
        ),
      );

      final apiService = ApiService(
        dio: mockDio,
        storageService: storageService,
        isMockMode: false,
      );

      final result = await apiService.syncOfflineDatabase();
      expect(result, isFalse, reason: 'Must return false when backend API is unreachable');
    });

    test('syncOfflineDatabase pings API, fetches courses and caches them in storageService', () async {
      final mockCourses = [
        {
          'id': 10,
          'title': 'Курс Амоксициллина',
          'is_active': true,
          'dosage_instruction': '1 таб 2 раза в день',
        }
      ];

      final mockDio = Dio(BaseOptions(baseUrl: 'http://localhost/api'));
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/reference-medicines')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'data': []},
                ),
              );
            }
            if (options.path.contains('/intake-courses')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'data': mockCourses},
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final apiService = ApiService(
        dio: mockDio,
        storageService: storageService,
        isMockMode: false,
      );

      final result = await apiService.syncOfflineDatabase();
      expect(result, isTrue, reason: 'Must return true when backend API is reachable');

      final cached = await storageService.getCachedActiveCourses();
      expect(cached, isNotNull);
      final decoded = jsonDecode(cached!) as List;
      expect(decoded.length, 1);
      expect(decoded[0]['title'], 'Курс Амоксициллина');
    });
  });
}
