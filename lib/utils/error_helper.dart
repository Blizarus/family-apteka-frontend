import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../widgets/toast_helper.dart';

/// Утилита централизованной обработки сетевых и прикладных ошибок (DEF-36).
/// Преобразует технические исключения DioException и системные сбои
/// в понятные и тактичные сообщения на русском языке для пользователя.
class ErrorHelper {
  /// Извлекает понятное пользователю сообщение об ошибке
  static String getMessage(dynamic error) {
    if (error == null) return 'Неизвестная ошибка';

    if (error is DioException) {
      return _formatDioError(error);
    }

    if (error is SocketException) {
      return 'Отсутствует подключение к сети. Проверьте интернет-соединение.';
    }

    if (error is TimeoutException) {
      return 'Превышено время ожидания ответа от сервера.';
    }

    final str = error.toString();

    // Если в строковом представлении содержится неперехваченный DioException
    if (str.contains('DioException')) {
      if (str.contains('connection error') || str.contains('Connection refused')) {
        return 'Не удалось подключиться к серверу. Проверьте подключение к сети.';
      }
      if (str.contains('401')) {
        return 'Сессия авторизации истекла. Пожалуйста, выполните вход повторно.';
      }
      if (str.contains('403')) {
        return 'Доступ к указанному действию ограничен (IDOR / недостаточные права).';
      }
      if (str.contains('404')) {
        return 'Запрашиваемый ресурс или запись не найдены.';
      }
      if (str.contains('409')) {
        return 'Конфликт данных: действие уже выполнено или запись заблокирована.';
      }
      if (str.contains('422')) {
        return 'Некорректные параметры запроса. Проверьте введённые данные.';
      }
      if (str.contains('500') || str.contains('502') || str.contains('503')) {
        return 'На сервере ведутся технические работы. Попробуйте позже.';
      }
      return 'Ошибка сетевого соединения с сервером.';
    }

    return str.replaceFirst('Exception: ', '').trim();
  }

  /// Форматирует DioException с разбором полезной нагрузки сервера (JSON message)
  static String _formatDioError(DioException dioError) {
    // 1. Попытка извлечь человекочитаемое сообщение от бэкенда Laravel
    final response = dioError.response;
    if (response != null && response.data != null) {
      final data = response.data;
      if (data is Map) {
        if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
          final serverMsg = data['message'].toString().trim();
          // Если сервер вернул стандартный английский текст валидации
          if (serverMsg == 'The given data was invalid.') {
            if (data['errors'] is Map) {
              final errMap = data['errors'] as Map;
              final firstErr = errMap.values.first;
              if (firstErr is List && firstErr.isNotEmpty) {
                return firstErr.first.toString();
              }
            }
            return 'Проверьте правильность заполнения всех обязательных полей.';
          }
          return serverMsg;
        }

        if (data['error'] != null && data['error'].toString().trim().isNotEmpty) {
          return data['error'].toString().trim();
        }

        if (data['errors'] is Map) {
          final errMap = data['errors'] as Map;
          final messages = <String>[];
          for (final val in errMap.values) {
            if (val is List) {
              messages.addAll(val.map((e) => e.toString()));
            } else if (val != null) {
              messages.add(val.toString());
            }
          }
          if (messages.isNotEmpty) {
            return messages.join('. ');
          }
        }
      } else if (data is String && data.isNotEmpty && !data.contains('<!DOCTYPE')) {
        return data.trim();
      }
    }

    // 2. Статусные коды HTTP
    final statusCode = response?.statusCode;
    if (statusCode != null) {
      switch (statusCode) {
        case 400:
          return 'Некорректный запрос к серверу.';
        case 401:
          return 'Сессия авторизации завершена. Пожалуйста, выполните вход заново.';
        case 403:
          return 'Доступ к данному действию запрещён (IDOR protection).';
        case 404:
          return 'Запрашиваемые данные не найдены на сервере.';
        case 409:
          return 'Конфликт состояния данных: операция уже выполнена или отменена.';
        case 422:
          return 'Введены некорректные данные. Пожалуйста, проверьте введённые значения.';
        case 429:
          return 'Слишком много запросов. Пожалуйста, подождите 1 минуту.';
        case 500:
        case 502:
        case 503:
        case 504:
          return 'Сервер временно недоступен. Попробуйте повторить попытку позже.';
      }
    }

    // 3. Типы сетевых сбоев Dio
    switch (dioError.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Превышено время ожидания ответа сервера. Проверьте интернет-соединение.';
      case DioExceptionType.connectionError:
        return 'Не удалось связаться с сервером. Проверьте мобильную сеть или Wi-Fi.';
      case DioExceptionType.badCertificate:
        return 'Ошибка безопасного TLS-соединения с сервером.';
      case DioExceptionType.cancel:
        return 'Запрос был отменён.';
      case DioExceptionType.badResponse:
        return 'Сервер вернул ошибку при обработке запроса.';
      case DioExceptionType.unknown:
      default:
        return 'Ошибка сетевого взаимодействия. Проверьте интернет-соединение.';
    }
  }

  /// Показывает ошибку пользователю через ToastHelper с локализованным текстом
  static void showError(BuildContext context, dynamic error, {String? prefix}) {
    final msg = getMessage(error);
    final fullMessage = prefix != null ? '$prefix: $msg' : msg;
    ToastHelper.showError(context, fullMessage);
  }
}
