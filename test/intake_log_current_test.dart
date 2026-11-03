import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/intake_log.dart';

void main() {
  group('DEF-07: Dynamic isCurrent calculation tests (CWE-547)', () {
    test('DEF-07: Scheduled at 10:00, current time 10:15 -> isCurrent is true', () {
      final now = DateTime(2026, 11, 3, 10, 15);
      final json = {
        'id': 1,
        'medicineName': 'Ибупрофен',
        'time': '10:00',
        'status': 'scheduled',
        'taken': false,
      };

      final log = IntakeLog.fromJson(json, currentTime: now);
      expect(log.isCurrent, isTrue);
    });

    test('DEF-07: Scheduled at 10:00, current time 15:00 (+5 hours late) -> isCurrent is false', () {
      final now = DateTime(2026, 11, 3, 15, 0);
      final json = {
        'id': 2,
        'medicineName': 'Ибупрофен',
        'time': '10:00',
        'status': 'scheduled',
        'taken': false,
      };

      final log = IntakeLog.fromJson(json, currentTime: now);
      expect(log.isCurrent, isFalse);
    });

    test('DEF-07: Scheduled at 10:00, current time 08:00 (2 hours before) -> isCurrent is false', () {
      final now = DateTime(2026, 11, 3, 8, 0);
      final json = {
        'id': 3,
        'medicineName': 'Ибупрофен',
        'time': '10:00',
        'status': 'scheduled',
        'taken': false,
      };

      final log = IntakeLog.fromJson(json, currentTime: now);
      expect(log.isCurrent, isFalse);
    });

    test('DEF-07: Scheduled at 10:00, current time 10:15, but taken: true -> isCurrent is false', () {
      final now = DateTime(2026, 11, 3, 10, 15);
      final json = {
        'id': 4,
        'medicineName': 'Ибупрофен',
        'time': '10:00',
        'status': 'taken',
        'taken': true,
      };

      final log = IntakeLog.fromJson(json, currentTime: now);
      expect(log.isCurrent, isFalse);
    });

    test('DEF-07: Scheduled at 10:00, current time 10:15, but status: skipped -> isCurrent is false', () {
      final now = DateTime(2026, 11, 3, 10, 15);
      final json = {
        'id': 5,
        'medicineName': 'Ибупрофен',
        'time': '10:00',
        'status': 'skipped',
        'taken': false,
      };

      final log = IntakeLog.fromJson(json, currentTime: now);
      expect(log.isCurrent, isFalse);
    });

    test('DEF-07: Server explicit flag {"is_current": true} forces isCurrent to true regardless of time', () {
      final now = DateTime(2026, 11, 3, 18, 0);
      final json = {
        'id': 6,
        'medicineName': 'Ибупрофен',
        'time': '10:00',
        'is_current': true,
        'status': 'scheduled',
        'taken': false,
      };

      final log = IntakeLog.fromJson(json, currentTime: now);
      expect(log.isCurrent, isTrue);
    });

    test('DEF-07: Server explicit flag {"isCurrent": false} forces isCurrent to false', () {
      final now = DateTime(2026, 11, 3, 10, 15);
      final json = {
        'id': 7,
        'medicineName': 'Ибупрофен',
        'time': '10:00',
        'isCurrent': false,
        'status': 'scheduled',
        'taken': false,
      };

      final log = IntakeLog.fromJson(json, currentTime: now);
      expect(log.isCurrent, isFalse);
    });
  });
}
