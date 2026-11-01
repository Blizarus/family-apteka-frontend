import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/parse_helper.dart';
import 'package:frontend/models/medicine.dart';
import 'package:frontend/models/intake_log.dart';
import 'package:frontend/models/shopping_item.dart';
import 'package:frontend/models/adherence_report.dart';
import 'package:frontend/models/profile.dart';
import 'package:frontend/models/medicine_box.dart';
import 'package:frontend/models/medical_note.dart';

void main() {
  group('ParseHelper Tests', () {
    test('parseDouble parses int, double, decimal strings, null, and fallback', () {
      expect(ParseHelper.parseDouble(10), 10.0);
      expect(ParseHelper.parseDouble(0.5), 0.5);
      expect(ParseHelper.parseDouble('10.000'), 10.0);
      expect(ParseHelper.parseDouble('0.500'), 0.5);
      expect(ParseHelper.parseDouble('2.0'), 2.0);
      expect(ParseHelper.parseDouble('1,5'), 1.5);
      expect(ParseHelper.parseDouble(null), 0.0);
      expect(ParseHelper.parseDouble(null, 5.5), 5.5);
      expect(ParseHelper.parseDouble(''), 0.0);
      expect(ParseHelper.parseDouble('   '), 0.0);
      expect(ParseHelper.parseDouble('abc'), 0.0);
      expect(ParseHelper.parseDouble('abc', 3.14), 3.14);
    });

    test('parseNullableDouble returns null for empty/invalid inputs', () {
      expect(ParseHelper.parseNullableDouble(10), 10.0);
      expect(ParseHelper.parseNullableDouble(0.5), 0.5);
      expect(ParseHelper.parseNullableDouble('10.000'), 10.0);
      expect(ParseHelper.parseNullableDouble('0.500'), 0.5);
      expect(ParseHelper.parseNullableDouble('1,75'), 1.75);
      expect(ParseHelper.parseNullableDouble(null), isNull);
      expect(ParseHelper.parseNullableDouble(''), isNull);
      expect(ParseHelper.parseNullableDouble('   '), isNull);
      expect(ParseHelper.parseNullableDouble('abc'), isNull);
    });

    test('parseInt parses numbers, decimal strings, and handles fallbacks', () {
      expect(ParseHelper.parseInt(10), 10);
      expect(ParseHelper.parseInt(10.0), 10);
      expect(ParseHelper.parseInt(10.8), 10);
      expect(ParseHelper.parseInt('10'), 10);
      expect(ParseHelper.parseInt('10.000'), 10);
      expect(ParseHelper.parseInt('0.500'), 0);
      expect(ParseHelper.parseInt('5.9'), 5);
      expect(ParseHelper.parseInt('6,5'), 6);
      expect(ParseHelper.parseInt(null), 0);
      expect(ParseHelper.parseInt(null, 7), 7);
      expect(ParseHelper.parseInt(''), 0);
      expect(ParseHelper.parseInt('abc'), 0);
      expect(ParseHelper.parseInt('abc', 42), 42);
    });

    test('parseNullableInt parses valid values and returns null for invalid', () {
      expect(ParseHelper.parseNullableInt(10), 10);
      expect(ParseHelper.parseNullableInt(10.0), 10);
      expect(ParseHelper.parseNullableInt('10.000'), 10);
      expect(ParseHelper.parseNullableInt('42'), 42);
      expect(ParseHelper.parseNullableInt(null), isNull);
      expect(ParseHelper.parseNullableInt(''), isNull);
      expect(ParseHelper.parseNullableInt('abc'), isNull);
    });

    test('formatQuantity & formatAny display clean numbers without trailing .0', () {
      expect(ParseHelper.formatQuantity(10.0), '10');
      expect(ParseHelper.formatQuantity(10), '10');
      expect(ParseHelper.formatQuantity(0.5), '0.5');
      expect(ParseHelper.formatQuantity(1.500), '1.5');
      expect(ParseHelper.formatQuantity(0.0), '0');
      expect(ParseHelper.formatQuantity(null), '0');

      expect(ParseHelper.formatAny('10.000'), '10');
      expect(ParseHelper.formatAny('0.500'), '0.5');
      expect(ParseHelper.formatAny(null), '0');
      expect(ParseHelper.formatAny('invalid', 'N/A'), 'N/A');
    });
  });

  group('Medicine Model Parsing Tests', () {
    test('Medicine.fromJson handles MySQL decimal strings and fractional quantity', () {
      final json = {
        'id': '10',
        'boxId': '1',
        'name': 'Ибупрофен суспензия',
        'substance': 'Ибупрофен',
        'form': 'Суспензия',
        'quantity': '0.500',
        'total': '100.000',
        'low_stock_threshold': '5.000',
        'days_after_opening': '30',
        'is_prescription': false,
      };

      final med = Medicine.fromJson(json);

      expect(med.id, 10);
      expect(med.boxId, 1);
      expect(med.name, 'Ибупрофен суспензия');
      expect(med.remaining, 0.5);
      expect(med.total, 100.0);
      expect(med.lowStockThreshold, 5.0);
      expect(med.daysAfterOpening, 30);
      expect(med.remainingDisplay, '0.5');
      expect(med.totalDisplay, '100');
      expect(med.lowStockThresholdDisplay, '5');
      expect(med.isLowStock, isTrue); // 0.5 <= 5.0
    });

    test('Medicine.copyWith preserves and updates fractional quantities', () {
      const med = Medicine(
        id: 1,
        boxId: 1,
        name: 'Парацетамол',
        substance: 'Парацетамол',
        form: 'Таблетки',
        remaining: 10,
        total: 20,
        expiry: '12.2028',
        status: 'ok',
      );

      final updated = med.copyWith(remaining: 0.5);
      expect(updated.remaining, 0.5);
      expect(updated.remainingDisplay, '0.5');
      expect(updated.total, 20.0);
      expect(updated.totalDisplay, '20');
    });
  });

  group('IntakeLog Model Parsing Tests', () {
    test('IntakeLog.fromJson handles realistic MySQL decimal server responses', () {
      final serverJson = {
        'id': '201',
        'profile_id': '2',
        'medicine_id': '15',
        'quantity_taken': '0.500',
        'dosage_quantity': '0.500',
        'scheduled_time': '2026-11-02 14:00:00',
        'status': 'taken',
        'taken': true,
        'rule': 'После обеда • 0.5 таб.',
        'medicine': {
          'id': 15,
          'custom_trade_name': 'Амоксициллин',
          'quantity': '15.500',
          'quantity_unit': 'Таблетки',
        },
        'intake_course': {
          'title': 'Курс терапии',
          'dosage_quantity': '0.500',
        },
      };

      final log = IntakeLog.fromJson(serverJson);

      expect(log.id, 201);
      expect(log.profileId, 2);
      expect(log.medicineId, 15);
      expect(log.medicineName, 'Амоксициллин');
      expect(log.quantityTaken, 0.5);
      expect(log.dosageQuantity, 0.5);
      expect(log.remaining, 15.5);
      expect(log.isTaken, isTrue);
      expect(log.status, 'taken');
      expect(log.unit, contains('таб'));
    });

    test('IntakeLog fallback extracts fractional dosage from rule when dosage_quantity missing', () {
      final json = {
        'id': 301,
        'profileId': 1,
        'medicineName': 'Дротаверин',
        'form': 'Таблетки',
        'time': '10:00',
        'rule': 'При спазмах • 1.5 таб.',
        'course': 'По требованию',
      };

      final log = IntakeLog.fromJson(json);

      expect(log.dosageQuantity, 1.5);
      expect(log.unit, contains('таб'));
    });
  });

  group('ShoppingItem & AdherenceReport Robust Parsing Tests', () {
    test('ShoppingItem.fromJson parses string counts and null IDs safely', () {
      final json = {
        'id': 'shop-1',
        'name': 'Аспирин Кардио',
        'count': '3.000',
        'profile_id': '2',
        'source_note_id': '10',
        'isPurchased': false,
      };

      final item = ShoppingItem.fromJson(json);

      expect(item.id, 'shop-1');
      expect(item.name, 'Аспирин Кардио');
      expect(item.count, 3);
      expect(item.profileId, 2);
      expect(item.sourceNoteId, 10);
      expect(item.isPurchased, isFalse);
    });

    test('AdherenceReport.fromJson parses MySQL numeric strings without casting errors', () {
      final reportJson = {
        'period': {
          'type': '7_days',
          'start_date': '2026-10-26',
          'end_date': '2026-11-02',
        },
        'scheduled_count': '14',
        'taken_count': '12',
        'missed_count': '2',
        'adherence_rate': '85.714',
        'streak_days': '5',
        'daily_stats': [
          {
            'date': '2026-10-26',
            'scheduled': '2',
            'taken': '2',
            'missed': '0',
          },
          {
            'date': '2026-10-27',
            'scheduled': '2',
            'taken': '1',
            'missed': '1',
          },
        ],
        'medicines_summary': [
          {
            'medicine_id': '1',
            'name': 'Ибупрофен 400 мг',
            'scheduled_count': '7',
            'taken_count': '6',
            'missed_count': '1',
            'adherence_rate': '85.700',
          },
        ],
      };

      final report = AdherenceReport.fromJson(reportJson);

      expect(report.scheduledCount, 14);
      expect(report.takenCount, 12);
      expect(report.missedCount, 2);
      expect(report.adherenceRate, 85.714);
      expect(report.streakDays, 5);
      expect(report.complianceLevelLabel, 'Высокий комплаенс');

      expect(report.dailyStats.length, 2);
      expect(report.dailyStats[0].scheduled, 2);
      expect(report.dailyStats[0].isFullSuccess, isTrue);
      expect(report.dailyStats[1].missed, 1);
      expect(report.dailyStats[1].hasMissed, isTrue);

      expect(report.medicinesSummary.length, 1);
      expect(report.medicinesSummary[0].medicineId, 1);
      expect(report.medicinesSummary[0].adherenceRate, 85.7);
    });

    test('Profile & MedicineBox fromJson safely handle string IDs and counts', () {
      final profileJson = {
        'id': '5',
        'name': 'Алексей',
        'notes': 'Родитель',
        'active_courses_count': '3',
      };
      final profile = Profile.fromJson(profileJson);
      expect(profile.id, 5);
      expect(profile.subtitle, '3 курса сегодня');

      final boxJson = {
        'id': '2',
        'name': 'Автомобильная',
        'box_type': 'car',
        'medicines_count': '6',
      };
      final box = MedicineBox.fromJson(boxJson);
      expect(box.id, 2);
      expect(box.count, 6);
      expect(box.icon, '🚗');
    });

    test('PrescribedMedicineItem parses string counts and formats cleanly', () {
      final itemJson = {
        'name': 'Амоксиклав',
        'dosage': '1 таб. 2 р/д',
        'status': 'inStock',
        'locationInfo': 'Домашняя аптечка, 14 шт.',
        'remainingCount': '14.000',
        'neededCount': '14.000',
      };

      final item = PrescribedMedicineItem.fromJson(itemJson);
      expect(item.remainingCount, 14.0);
      expect(item.remainingCountDisplay, '14');
      expect(item.neededCount, 14.0);
      expect(item.neededCountDisplay, '14');
      expect(item.isInStock, isTrue);
    });
  });
}
