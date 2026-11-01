import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Модель данных входящего push-уведомления (FCM payload)
class PushNotificationPayload {
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  PushNotificationPayload({
    required this.title,
    required this.body,
    Map<String, dynamic>? data,
    DateTime? timestamp,
  })  : data = data ?? const {},
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PushNotificationPayload.fromJson(Map<String, dynamic> json) =>
      PushNotificationPayload(
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        data: json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : const {},
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  @override
  String toString() =>
      'PushNotificationPayload(title: $title, body: $body, data: $data, timestamp: $timestamp)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PushNotificationPayload &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          body == other.body;

  @override
  int get hashCode => title.hashCode ^ body.hashCode;
}

/// Сервис управления Push-уведомлениями (FCM)
/// Поддерживает архитектуру Singleton / Factory с возможностью внедрения StorageService.
class PushNotificationService {
  static PushNotificationService? _instance;

  final StorageService storageService;
  final StreamController<PushNotificationPayload> _messageController;
  String? _deviceToken;

  PushNotificationService._internal({
    required this.storageService,
    StreamController<PushNotificationPayload>? messageController,
  }) : _messageController =
            messageController ?? StreamController<PushNotificationPayload>.broadcast();

  factory PushNotificationService({
    StorageService? storageService,
  }) {
    if (_instance == null) {
      _instance = PushNotificationService._internal(
        storageService: storageService ?? StorageService(),
      );
    } else if (storageService != null) {
      return PushNotificationService._internal(storageService: storageService);
    }
    return _instance!;
  }

  static PushNotificationService get instance => PushNotificationService();

  @visibleForTesting
  static void resetInstanceForTesting() {
    _instance?._messageController.close();
    _instance = null;
  }

  /// Получение FCM-токена устройства (генерация mock/device токена fcm_device_token_...)
  Future<String?> getDeviceToken() async {
    if (_deviceToken != null) {
      return _deviceToken;
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _deviceToken = 'fcm_device_token_${timestamp}_mock';
    return _deviceToken;
  }

  @visibleForTesting
  void setDeviceTokenForTesting(String? token) {
    _deviceToken = token;
  }

  /// Поток входящих push-уведомлений в реальном времени
  Stream<PushNotificationPayload> get onMessageStream => _messageController.stream;

  /// Имитация доставки входящего push-уведомления
  void simulateIncomingNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    final payload = PushNotificationPayload(
      title: title,
      body: body,
      data: data ?? const {},
    );
    _messageController.add(payload);
  }

  /// Регистрация FCM-токена на сервере через ApiService и сохранение флага активности
  Future<bool> registerTokenWithBackend(
    ApiService apiService, {
    String platform = 'flutter',
  }) async {
    final token = await getDeviceToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    final success = await apiService.registerFcmToken(token, platform: platform);
    if (success) {
      await storageService.setPushEnabled(true);
    }
    return success;
  }

  /// Проверка статуса активации push-уведомлений
  Future<bool> isPushEnabled() => storageService.isPushEnabled();

  /// Включение или отключение push-уведомлений
  Future<void> setPushEnabled(bool enabled) => storageService.setPushEnabled(enabled);

  /// Закрытие контроллера стрима
  void dispose() {
    _messageController.close();
  }
}
