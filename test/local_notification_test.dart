import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/local_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalNotificationService Tests', () {
    late LocalNotificationService service;

    setUp(() {
      LocalNotificationService.resetInstanceForTesting();
      service = LocalNotificationService(mock: true);
    });

    test('1. Initialize service sets isInitialized flag to true', () async {
      expect(service.isInitialized, isFalse);
      final ok = await service.initialize();
      expect(ok, isTrue);
      expect(service.isInitialized, isTrue);
    });

    test('2. requestPermissions succeeds in mock/test mode', () async {
      final granted = await service.requestPermissions();
      expect(granted, isTrue);
    });

    test('3. Scheduling, cancelling, and clear reminders complete without errors', () async {
      await service.initialize();

      await service.scheduleIntakeReminder(
        id: 101,
        title: 'Приём Парацетамола',
        body: '1 таблетка после еды',
        scheduledDate: DateTime.now().add(const Duration(hours: 2)),
      );

      await service.cancelReminder(101);
      await service.cancelAll();
    });
  });
}
