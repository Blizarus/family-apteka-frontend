import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/intake_log.dart';

void main() {
  group('DEF-56: IntakeLog naming and course display tests', () {
    test('extracts trade_name from medicine.reference_medicine when custom_trade_name is null', () {
      final json = {
        'id': 101,
        'profile_id': 1,
        'medicine': {
          'id': 10,
          'custom_trade_name': null,
          'reference_medicine': {
            'trade_name': 'Амоксициллин Сандоз',
            'name': 'Амоксициллин',
          },
        },
        'status': 'scheduled',
      };

      final log = IntakeLog.fromJson(json);
      expect(log.medicineName, equals('Амоксициллин Сандоз'));
    });

    test('extracts trade_name from intake_course.medicine.reference_medicine', () {
      final json = {
        'id': 102,
        'profile_id': 1,
        'intake_course': {
          'id': 5,
          'title': 'Курс витамина D',
          'medicine': {
            'id': 20,
            'custom_trade_name': null,
            'reference_medicine': {
              'trade_name': 'Аквадетрим',
              'name': 'Колекальциферол',
            },
          },
        },
        'status': 'scheduled',
      };

      final log = IntakeLog.fromJson(json);
      expect(log.medicineName, equals('Аквадетрим'));
    });

    test('extracts name from reference_medicine when trade_name is null', () {
      final json = {
        'id': 103,
        'profile_id': 1,
        'medicine': {
          'id': 30,
          'custom_trade_name': null,
          'reference_medicine': {
            'trade_name': null,
            'name': 'Парацетамол',
          },
        },
        'status': 'scheduled',
      };

      final log = IntakeLog.fromJson(json);
      expect(log.medicineName, equals('Парацетамол'));
    });

    test('courseDisplay does not duplicate "Курс:" prefix', () {
      final logWithPrefix = IntakeLog(
        id: 1,
        profileId: 1,
        medicineName: 'Амоксициллин',
        form: 'Таблетки',
        time: '08:00',
        rule: 'После еды',
        course: 'Курс: Амоксициллин Сандоз • 1 таблетка',
      );

      final logWithoutPrefix = IntakeLog(
        id: 2,
        profileId: 1,
        medicineName: 'Амоксициллин',
        form: 'Таблетки',
        time: '08:00',
        rule: 'После еды',
        course: 'Амоксициллин Сандоз • 1 таблетка',
      );

      expect(logWithPrefix.courseDisplay, equals('Курс: Амоксициллин Сандоз • 1 таблетка'));
      expect(logWithoutPrefix.courseDisplay, equals('Курс: Амоксициллин Сандоз • 1 таблетка'));
    });
  });
}
