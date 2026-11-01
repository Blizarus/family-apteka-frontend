import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/storage_service.dart';
import 'package:frontend/services/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PushNotificationService.resetInstanceForTesting();
  });

  tearDown(() {
    PushNotificationService.resetInstanceForTesting();
  });

  group('1. PushNotificationService Token & Stream Tests', () {
    test('getDeviceToken generates valid fcm_device_token_ and caches it', () async {
      final storage = StorageService();
      final service = PushNotificationService(storageService: storage);

      final token1 = await service.getDeviceToken();
      expect(token1, isNotNull);
      expect(token1, startsWith('fcm_device_token_'));

      final token2 = await service.getDeviceToken();
      expect(token2, equals(token1));
    });

    test('onMessageStream receives simulated incoming notifications', () async {
      final storage = StorageService();
      final service = PushNotificationService(storageService: storage);

      final receivedPayloads = <PushNotificationPayload>[];
      final subscription = service.onMessageStream.listen((payload) {
        receivedPayloads.add(payload);
      });

      service.simulateIncomingNotification(
        title: 'Приём лекарства',
        body: 'Пора принять Аспирин 100мг',
        data: {'medicine_id': 1, 'course_id': 5},
      );

      service.simulateIncomingNotification(
        title: 'Истекает срок годности',
        body: 'Нурофен годен ещё 7 дней',
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(receivedPayloads.length, 2);
      expect(receivedPayloads[0].title, 'Приём лекарства');
      expect(receivedPayloads[0].body, 'Пора принять Аспирин 100мг');
      expect(receivedPayloads[0].data['medicine_id'], 1);
      expect(receivedPayloads[1].title, 'Истекает срок годности');
      expect(receivedPayloads[1].data, isEmpty);

      await subscription.cancel();
      service.dispose();
    });

    test('PushNotificationPayload serialization to/from JSON works correctly', () {
      final payload = PushNotificationPayload(
        title: 'Заголовок',
        body: 'Текст оповещения',
        data: {'type': 'intake_reminder'},
      );

      final json = payload.toJson();
      expect(json['title'], 'Заголовок');
      expect(json['body'], 'Текст оповещения');
      expect(json['data']['type'], 'intake_reminder');

      final reconstructed = PushNotificationPayload.fromJson(json);
      expect(reconstructed.title, 'Заголовок');
      expect(reconstructed.body, 'Текст оповещения');
      expect(reconstructed.data['type'], 'intake_reminder');
      expect(reconstructed, equals(payload));
    });
  });

  group('2. StorageService isPushEnabled & Token Registration Tests', () {
    test('StorageService correctly stores, toggles and clears pushEnabled state', () async {
      final storage = StorageService();
      expect(await storage.isPushEnabled(), isFalse);

      await storage.setPushEnabled(true);
      expect(await storage.isPushEnabled(), isTrue);

      await storage.setPushEnabled(false);
      expect(await storage.isPushEnabled(), isFalse);

      await storage.setPushEnabled(true);
      await storage.clearAllData();
      expect(await storage.isPushEnabled(), isFalse);
    });

    test('registerTokenWithBackend registers token and enables push on success', () async {
      final storage = StorageService();
      final service = PushNotificationService(storageService: storage);
      final apiService = ApiService(isMockMode: true, storageService: storage);

      expect(await service.isPushEnabled(), isFalse);

      final result = await service.registerTokenWithBackend(apiService, platform: 'flutter');
      expect(result, isTrue);
      expect(await service.isPushEnabled(), isTrue);
    });

    test('registerTokenWithBackend fails and leaves push disabled when token is empty', () async {
      final storage = StorageService();
      final service = PushNotificationService(storageService: storage);
      final apiService = ApiService(isMockMode: true, storageService: storage);

      service.setDeviceTokenForTesting('');

      final result = await service.registerTokenWithBackend(apiService);
      expect(result, isFalse);
      expect(await service.isPushEnabled(), isFalse);
    });
  });

  group('3. ApiService FCM Endpoints with Mock & Network Responses', () {
    test('ApiService.registerFcmToken in mock mode returns true', () async {
      final apiService = ApiService(isMockMode: true);
      final result = await apiService.registerFcmToken('fcm_mock_token_123', platform: 'flutter');
      expect(result, isTrue);
    });

    test('ApiService.sendTestPush in mock mode returns true', () async {
      final apiService = ApiService(isMockMode: true);
      final result = await apiService.sendTestPush(
        title: 'Тест пуша',
        body: 'Проверка канала push-уведомлений',
      );
      expect(result, isTrue);
    });

    test('ApiService.registerFcmToken handles custom Dio 200 response', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/notifications/fcm-token') {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'message': 'FCM token registered successfully',
                  'fcm_token': options.data['fcm_token'],
                  'platform': options.data['platform'],
                },
              ),
            );
          }
          return handler.next(options);
        },
      ));

      final apiService = ApiService(dio: dio, isMockMode: false);
      final result = await apiService.registerFcmToken('token_network_xyz', platform: 'android');
      expect(result, isTrue);
    });

    test('ApiService.registerFcmToken returns false on network error', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 500,
                statusMessage: 'Internal Server Error',
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ));

      final apiService = ApiService(dio: dio, isMockMode: false);
      final result = await apiService.registerFcmToken('token_fail');
      expect(result, isFalse);
    });

    test('ApiService.sendTestPush handles custom Dio 200 response', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/notifications/test-push') {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'message': 'Test push notification queued/sent',
                  'dispatched': true,
                },
              ),
            );
          }
          return handler.next(options);
        },
      ));

      final apiService = ApiService(dio: dio, isMockMode: false);
      final result = await apiService.sendTestPush(title: 'Тест', body: 'Содержимое');
      expect(result, isTrue);
    });
  });
}
