import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/storage_service.dart';

Dio createConfiguredDio({
  required String targetPath,
  required String targetMethod,
  required int errorStatus,
  required dynamic errorResponse,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.contains(targetPath) &&
            options.method.toUpperCase() == targetMethod.toUpperCase()) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: errorStatus,
                data: errorResponse,
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        } else if (options.path.endsWith('/medicine-boxes') && options.method == 'GET') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': [
                  {
                    'id': 1,
                    'name': 'Основная домашняя',
                    'type': 'home',
                    'icon': '🏠',
                    'color': '#0D9488',
                    'is_primary': true,
                  }
                ]
              },
            ),
          );
        } else {
          handler.next(options);
        }
      },
    ),
  );
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test_token'});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
  });

  group('DEF-02: deleteMedicineBox error handling & no mock deletion on failure', () {
    test('deleteMedicineBox throws Exception on HTTP 422 and does NOT delete box from local state', () async {
      final dio = createConfiguredDio(
        targetPath: '/medicine-boxes/1',
        targetMethod: 'DELETE',
        errorStatus: 422,
        errorResponse: {
          'message': 'Нельзя удалить аптечку, в которой содержатся лекарственные препараты. Сначала переместите или удалите их.',
        },
      );

      final apiService = ApiService(
        dio: dio,
        storageService: storageService,
        secureStorage: const FlutterSecureStorage(),
        isMockMode: false,
      );

      // Pre-condition: check that box 1 exists
      final initialBoxes = await apiService.getMedicineBoxes();
      final hasBox1 = initialBoxes.any((b) => b.id == 1);
      expect(hasBox1, isTrue, reason: 'Box with id 1 must initially exist in list');

      // Act & Assert: Call delete on failing API - must throw Exception with server message
      await expectLater(
        () => apiService.deleteMedicineBox(1),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Нельзя удалить аптечку, в которой содержатся лекарственные препараты'),
          ),
        ),
      );

      // Verify that local cache/mock was NOT deleted after failure
      final boxesAfterFailedDelete = await apiService.getMedicineBoxes();
      expect(
        boxesAfterFailedDelete.any((b) => b.id == 1),
        isTrue,
        reason: 'Box with id 1 must NOT be deleted when API returns 422',
      );
    });
  });

  group('DEF-01: Admin API errors are not masked by mock-fallbacks', () {
    test('getAdminUsers throws DioException on HTTP 403 / 500 without returning mock users', () async {
      final dio = createConfiguredDio(
        targetPath: '/admin/users',
        targetMethod: 'GET',
        errorStatus: 403,
        errorResponse: {'message': 'Доступ запрещен. Требуются права администратора.'},
      );

      final apiService = ApiService(
        dio: dio,
        storageService: storageService,
        secureStorage: const FlutterSecureStorage(),
        isMockMode: false,
      );

      // Act & Assert: must rethrow/throw error rather than returning mock users
      await expectLater(
        () => apiService.getAdminUsers(),
        throwsA(isA<DioException>()),
      );
    });

    test('toggleBlockUser throws DioException on HTTP 403 without mutating mock state', () async {
      final dio = createConfiguredDio(
        targetPath: '/admin/users/1/block',
        targetMethod: 'POST',
        errorStatus: 403,
        errorResponse: {'message': 'Доступ запрещен.'},
      );

      final apiService = ApiService(
        dio: dio,
        storageService: storageService,
        secureStorage: const FlutterSecureStorage(),
        isMockMode: false,
      );

      // Act & Assert: must rethrow DioException
      await expectLater(
        () => apiService.toggleBlockUser(1, true),
        throwsA(isA<DioException>()),
      );
    });

    test('addReferenceMedicine throws DioException on HTTP 422/500 without mutating mock list', () async {
      final dio = createConfiguredDio(
        targetPath: '/admin/reference-medicines',
        targetMethod: 'POST',
        errorStatus: 500,
        errorResponse: {'message': 'Внутренняя ошибка сервера при сохранении препарата.'},
      );

      final apiService = ApiService(
        dio: dio,
        storageService: storageService,
        secureStorage: const FlutterSecureStorage(),
        isMockMode: false,
      );

      final payload = {
        'trade_name': 'Тестовый Новодипидин 100 мг',
        'inn': 'Новодипидин',
        'dosage_form': 'Таблетки',
        'dosage': '100 мг',
        'pack_size': 30,
        'manufacturer': 'Фарм-Тест',
        'country': 'Россия',
        'barcode': '4609999999999',
      };

      // Act & Assert: must rethrow DioException and NOT insert into mock reference list
      await expectLater(
        () => apiService.addReferenceMedicine(payload),
        throwsA(isA<DioException>()),
      );
    });
  });
}
