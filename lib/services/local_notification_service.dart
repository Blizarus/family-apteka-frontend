import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Сервис локальных уведомлений и планирования напоминаний о приёме лекарств.
/// Использует flutter_local_notifications + timezone с поддержкой перепланирования
/// после перезагрузки устройства (BOOT_COMPLETED) и работы в фоне.
class LocalNotificationService {
  static LocalNotificationService? _instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool isInitialized = false;
  bool isMockMode = false;

  LocalNotificationService._internal({
    FlutterLocalNotificationsPlugin? plugin,
    bool? mock,
  })  : _notificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin(),
        isMockMode = mock ?? !kReleaseMode && (kIsWeb || !Platform.isAndroid && !Platform.isIOS);

  factory LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    bool? mock,
  }) {
    _instance ??= LocalNotificationService._internal(plugin: plugin, mock: mock);
    return _instance!;
  }

  static LocalNotificationService get instance => LocalNotificationService();

  @visibleForTesting
  static void resetInstanceForTesting() {
    _instance = null;
  }

  /// Инициализация часовых поясов и каналов уведомлений
  Future<bool> initialize() async {
    if (isInitialized) return true;

    try {
      tz.initializeTimeZones();
    } catch (_) {}

    if (isMockMode) {
      isInitialized = true;
      return true;
    }

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final success = await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          if (kDebugMode) {
            debugPrint('Нажатие на уведомление: ${details.payload}');
          }
        },
      );

      isInitialized = success ?? false;
      return isInitialized;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Ошибка инициализации LocalNotificationService: $e');
      }
      isInitialized = false;
      return false;
    }
  }

  /// Запрос системных разрешений на отправку уведомлений
  Future<bool> requestPermissions() async {
    if (isMockMode) return true;

    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Планирование разового напоминания о приёме лекарства на точное время
  Future<void> scheduleIntakeReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (isMockMode) return;

    if (!isInitialized) {
      await initialize();
    }

    try {
      final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);
      if (tzScheduled.isBefore(tz.TZDateTime.now(tz.local))) {
        return; // Прошедшие даты не планируем
      }

      const androidDetails = AndroidNotificationDetails(
        'intake_reminders_channel',
        'Напоминания о приёме лекарств',
        channelDescription: 'Своевременные оповещения о необходимости принять медикаменты',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Пора принять лекарство',
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzScheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Ошибка планирования уведомления #$id: $e');
      }
    }
  }

  /// Отмена запланированного уведомления
  Future<void> cancelReminder(int id) async {
    if (isMockMode) return;
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (_) {}
  }

  /// Отмена всех запланированных уведомлений
  Future<void> cancelAll() async {
    if (isMockMode) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
