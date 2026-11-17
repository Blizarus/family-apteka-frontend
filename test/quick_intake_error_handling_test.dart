import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DEF-37: Quick Intake Error Handling & No Silent Fallbacks', () {
    late StorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'test_token'});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
    });

    test('recordQuickIntake throws DioException on HTTP 404 and does NOT return fallback success', () async {
      final mockDio = Dio(BaseOptions(baseUrl: 'http://localhost/api'));
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 404,
                  data: {'message': 'Route Not Found'},
                ),
                type: DioExceptionType.badResponse,
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

      expect(
        () => apiService.recordQuickIntake(
          medicineId: 1,
          profileId: 1,
          quantity: 1.0,
        ),
        throwsA(isA<DioException>()),
      );
    });

    test('recordQuickIntake throws DioException on HTTP 405', () async {
      final mockDio = Dio(BaseOptions(baseUrl: 'http://localhost/api'));
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 405,
                  data: {'message': 'Method Not Allowed'},
                ),
                type: DioExceptionType.badResponse,
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

      expect(
        () => apiService.recordQuickIntake(
          medicineId: 1,
          profileId: 1,
          quantity: 1.0,
        ),
        throwsA(isA<DioException>()),
      );
    });
  });
}
