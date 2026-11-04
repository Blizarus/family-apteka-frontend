import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/error_helper.dart';

void main() {
  group('ErrorHelper Tests (DEF-36)', () {
    test('Extracts custom message from server response data', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/intake-logs/1/snooze'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/intake-logs/1/snooze'),
          statusCode: 409,
          data: {'message': 'Невозможно отложить уже принятый препарат.'},
        ),
        type: DioExceptionType.badResponse,
      );

      final msg = ErrorHelper.getMessage(dioError);
      expect(msg, 'Невозможно отложить уже принятый препарат.');
    });

    test('Extracts validation error from errors map', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/medicines'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/medicines'),
          statusCode: 422,
          data: {
            'message': 'The given data was invalid.',
            'errors': {
              'custom_trade_name': ['Название препарата обязательно для заполнения.'],
            },
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final msg = ErrorHelper.getMessage(dioError);
      expect(msg, 'Название препарата обязательно для заполнения.');
    });

    test('Handles 401 Unauthorized without data as expired session', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/dashboard'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/dashboard'),
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      );

      final msg = ErrorHelper.getMessage(dioError);
      expect(msg, contains('Сессия авторизации завершена'));
    });

    test('Handles connection timeout gracefully', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/intake-courses'),
        type: DioExceptionType.connectionTimeout,
      );

      final msg = ErrorHelper.getMessage(dioError);
      expect(msg, contains('Превышено время ожидания ответа сервера'));
    });

    test('Handles connection error (offline) gracefully', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/api/dashboard'),
        type: DioExceptionType.connectionError,
      );

      final msg = ErrorHelper.getMessage(dioError);
      expect(msg, contains('Не удалось связаться с сервером'));
    });

    test('Sanitizes string representation of DioException', () {
      const rawStr = 'DioException [bad response]: The request returned 403 Forbidden';
      final msg = ErrorHelper.getMessage(rawStr);
      expect(msg, contains('IDOR'));
      expect(msg, isNot(contains('DioException')));
    });

    test('Cleans standard Exception prefix', () {
      final ex = Exception('Пользователь не найден');
      final msg = ErrorHelper.getMessage(ex);
      expect(msg, 'Пользователь не найден');
    });
  });
}
