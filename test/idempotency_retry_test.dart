import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/intake_log.dart';
import 'package:frontend/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Idempotency Retry & Network Deduplication Tests', () {
    test('1. takeIntakeLog attaches X-Idempotency-Key header and idempotency_key body parameter', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.family-apteka.ru/api'));
      RequestOptions? capturedOptions;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'message': 'Приём лекарства успешно зафиксирован.',
                  'intake_log_id': 101,
                  'idempotent_replayed': false,
                  'data': {
                    'id': 101,
                    'is_taken': true,
                    'taken_at': DateTime.now().toIso8601String(),
                  },
                },
              ),
            );
          },
        ),
      );

      final apiService = ApiService(dio: dio, isMockMode: false);
      const testKey = 'idem-uuid-take-12345';

      final result = await apiService.takeIntakeLog(
        101,
        confirmWithoutStock: false,
        idempotencyKey: testKey,
      );

      expect(result['intake_log_id'], 101);
      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.headers['X-Idempotency-Key'], testKey);
      expect(capturedOptions!.data, isA<Map<String, dynamic>>());
      expect((capturedOptions!.data as Map)['idempotency_key'], testKey);
    });

    test('2. Repeated takeIntakeLog with same key receives replayed 200 response without error', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.family-apteka.ru/api'));
      int callCount = 0;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            callCount++;
            final isReplay = callCount > 1;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'message': isReplay
                      ? 'Повторный ответ: приём уже учтён (идемпотентность).'
                      : 'Приём лекарства успешно зафиксирован.',
                  'intake_log_id': 101,
                  'idempotent_replayed': isReplay,
                  'data': {
                    'id': 101,
                    'is_taken': true,
                  },
                },
              ),
            );
          },
        ),
      );

      final apiService = ApiService(dio: dio, isMockMode: false);
      const testKey = 'idem-replay-key-999';

      // Первый запрос
      final res1 = await apiService.takeIntakeLog(101, idempotencyKey: testKey);
      expect(res1['idempotent_replayed'], isFalse);

      // Повторный запрос с тем же ключом
      final res2 = await apiService.takeIntakeLog(101, idempotencyKey: testKey);
      expect(res2['idempotent_replayed'], isTrue);
      expect(res2['intake_log_id'], 101);
      expect(callCount, 2);
    });

    test('3. Mock mode: second takeIntakeLog returns already_taken without double stock decrement', () async {
      final apiService = ApiService(isMockMode: true);

      // Добавим лог с остатком 5.0
      apiService.addMockIntake(
        const IntakeLog(
          id: 555,
          profileId: 1,
          medicineName: 'Ибупрофен',
          dosageQuantity: 1.0,
          form: 'таблетка',
          time: '12:00',
          rule: 'после еды',
          status: 'scheduled',
          course: 'Курс 1',
          remaining: 5.0,
          medicineId: 10,
        ),
      );

      // Первый приём списывает остаток
      final firstRes = await apiService.takeIntakeLog(555, idempotencyKey: 'mock-key-555');
      expect(firstRes['already_taken'], isNull);
      expect(firstRes['remaining_quantity'], 4.0);

      // Повторный приём с тем же ключом не уменьшает остаток до 3.0
      final secondRes = await apiService.takeIntakeLog(555, idempotencyKey: 'mock-key-555');
      expect(secondRes['already_taken'], isTrue);
      expect(secondRes['remaining_quantity'], 4.0);
    });

    test('4. recordQuickIntake attaches idempotency_key to payload and header', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.family-apteka.ru/api'));
      RequestOptions? capturedOptions;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'success': true,
                  'intake_log_id': 888,
                  'message': 'Разовый приём зафиксирован.',
                },
              ),
            );
          },
        ),
      );

      final apiService = ApiService(dio: dio, isMockMode: false);
      const testKey = 'quick-idem-key-777';

      final res = await apiService.recordQuickIntake(
        medicineId: 10,
        profileId: 1,
        quantity: 2.0,
        symptom: 'Головная боль',
        idempotencyKey: testKey,
      );

      expect(res['success'], isTrue);
      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.headers['X-Idempotency-Key'], testKey);
      expect((capturedOptions!.data as Map)['idempotency_key'], testKey);
      expect((capturedOptions!.data as Map)['quantity'], 2.0);
    });
  });
}
