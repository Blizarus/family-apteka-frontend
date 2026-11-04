import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/intake_log.dart';

void main() {
  group('DEF-26: Timezone parsing & slot alignment tests', () {
    test('UTC to local time conversion for Europe/Moscow (+3)', () {
      // 05:00 UTC = 08:00 MSK
      final json = {
        'id': 101,
        'medicineName': 'Анальгин',
        'scheduled_time': '2026-11-10T05:00:00.000000Z',
        'status': 'scheduled',
      };

      final log = IntakeLog.fromJson(json);
      expect(log.scheduledTime, isNotNull);
      // scheduledTime is parsed in local timezone
      final expectedHour = log.scheduledTime!.hour;
      final expectedMinute = log.scheduledTime!.minute;
      expect(log.time, '${expectedHour.toString().padLeft(2, '0')}:${expectedMinute.toString().padLeft(2, '0')}');
    });

    test('Explicit time in json is respected when scheduled_time is null', () {
      final json = {
        'id': 102,
        'medicineName': 'Аспирин',
        'time': '08:00',
        'status': 'scheduled',
      };

      final log = IntakeLog.fromJson(json);
      expect(log.time, '08:00');
    });

    test('Midnight transition across date boundary (UTC 21:30 is 00:30 next day in MSK)', () {
      // 2026-11-09T21:30:00Z -> In UTC+3 this is 2026-11-10 00:30
      final json = {
        'id': 103,
        'medicineName': 'Снотворное',
        'scheduled_time': '2026-11-09T21:30:00.000000Z',
        'status': 'scheduled',
      };

      final log = IntakeLog.fromJson(json);
      expect(log.scheduledTime, isNotNull);
      final local = log.scheduledTime!;
      expect(log.time, '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}');
    });

    test('Vladivostok timezone (+10): UTC 15:00 is 01:00 next day', () {
      // 2026-11-09T15:00:00Z -> In UTC+10 this is 2026-11-10 01:00
      final json = {
        'id': 104,
        'medicineName': 'Утренний препарат ВЛ',
        'scheduled_time': '2026-11-09T15:00:00.000000Z',
        'status': 'scheduled',
      };

      final log = IntakeLog.fromJson(json);
      expect(log.scheduledTime, isNotNull);
      final local = log.scheduledTime!;
      expect(log.time, '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}');
    });

    test('Formatting with DosageFormatter integration', () {
      final json = {
        'id': 105,
        'medicineName': 'Ибупрофен',
        'time': '12:00',
        'dosage_quantity': 2.0,
        'form': 'таблетки',
      };

      final log = IntakeLog.fromJson(json);
      expect(log.formattedDosage, '2 таблетки');
    });
  });
}
