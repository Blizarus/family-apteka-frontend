import 'package:dio/dio.dart';

/// Утилита для преобразования технических ошибок сети и Dio в
/// понятные, лаконичные русскоязычные сообщения для пользователей.
class ApiErrorHandler {
  ApiErrorHandler._();

  /// Преобразует исключение в понятный пользователю текст.
  /// Исключает технические дампы Dio, ссылки на MDN и стектрейсы.
  static String format(Object error, {String defaultMessage = 'Не удалось выполнить операцию'}) {
    if (error is DioException) {
      return _formatDioException(error);
    }

    // Обычные системные исключения
    final errStr = error.toString();
    if (errStr.contains('SocketException') || errStr.contains('Connection refused')) {
      return 'Не удалось подключиться к серверу. Проверьте интернет-соединение.';
    }
    if (errStr.contains('TimeoutException')) {
      return 'Время ожидания ответа сервера истекло.';
    }

    return defaultMessage;
  }

  static String _formatDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Время ожидания сервера истекло. Проверьте интернет-соединение.';

      case DioExceptionType.connectionError:
        return 'Не удалось связаться с сервером. Проверьте интернет-соединение или адрес сервера в настройках.';

      case DioExceptionType.badCertificate:
        return 'Ошибка проверки SSL-сертификата безопасности сервера.';

      case DioExceptionType.cancel:
        return 'Запрос к серверу был отменён.';

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;

        // Если бэкенд вернул структурированный JSON с ошибками валидации Laravel (422)
        if (statusCode == 422 && data is Map<String, dynamic>) {
          if (data['errors'] is Map) {
            final errorsMap = data['errors'] as Map;
            if (errorsMap.isNotEmpty) {
              final firstField = errorsMap.values.first;
              if (firstField is List && firstField.isNotEmpty) {
                return firstField.first.toString();
              }
              return firstField.toString();
            }
          }
          if (data['message'] != null) {
            return data['message'].toString();
          }
          return 'Некорректно заполнены поля формы.';
        }

        // 401 Неавторизован
        if (statusCode == 401) {
          if (data is Map<String, dynamic> && data['message'] != null) {
            return data['message'].toString();
          }
          return 'Неверный адрес электронной почты или пароль.';
        }

        // 403 Доступ запрещён
        if (statusCode == 403) {
          if (data is Map<String, dynamic> && data['message'] != null) {
            return data['message'].toString();
          }
          return 'Доступ к ресурсу запрещён сервером (HTTP 403). Проверьте настройки сети или адрес сервера.';
        }

        // 404 Не найдено
        if (statusCode == 404) {
          return 'Запрошенный серверный маршрут или ресурс не найден (HTTP 404).';
        }

        // 429 Превышен лимит запросов
        if (statusCode == 429) {
          return 'Слишком много попыток. Пожалуйста, подождите 1 минуту перед следующим запросом.';
        }

        // 500-504 Ошибки бэкенда
        if (statusCode != null && statusCode >= 500 && statusCode < 600) {
          return 'Сервер временно недоступен (код $statusCode). Ведутся технические работы, попробуйте чуть позже.';
        }

        // Прочие ответы с JSON message
        if (data is Map<String, dynamic> && data['message'] != null) {
          final msg = data['message'].toString().trim();
          if (msg.isNotEmpty && !msg.startsWith('<!DOCTYPE')) {
            return msg;
          }
        }

        return 'Ошибка сервера (HTTP ${statusCode ?? 'неизвестен'}).';

      case DioExceptionType.unknown:
      default:
        final rawMsg = e.message ?? '';
        if (rawMsg.contains('SocketException') || rawMsg.contains('Connection refused')) {
          return 'Не удалось подключиться к серверу. Проверьте интернет или адрес в настройках.';
        }
        return 'Сетевая ошибка. Проверьте подключение к интернету.';
    }
  }
}
