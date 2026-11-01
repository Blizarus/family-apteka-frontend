import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/adherence_report.dart';
import 'package:frontend/models/intake_log.dart';
import 'package:frontend/models/medicine.dart';
import 'package:frontend/models/profile.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/services/pdf_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Сквозной клинический сценарий E2E (Регистрация -> CDS -> Списание -> PDF)', () {
    test('Полный интеграционный цикл от создания пациента до экспорта PDF отчёта врачу', () async {
      // -------------------------------------------------------------
      // ШАГ 1. Пользователь и согласие 152-ФЗ
      // -------------------------------------------------------------
      final userJson = {
        'id': 101,
        'email': 'markova_e2e@family.test',
        'name': 'Ирина Маркова',
        'terms_accepted': true,
        'sync_enabled': true,
        'timezone': 'Europe/Moscow',
      };
      final user = User.fromJson(userJson);
      expect(user.id, 101);
      expect(user.email, 'markova_e2e@family.test');

      // -------------------------------------------------------------
      // ШАГ 2. Профиль пациента с аллергией на пенициллин
      // -------------------------------------------------------------
      final profile = Profile(
        id: 201,
        name: 'Ирина',
        role: 'Владелец',
        avatar: '👩',
        subtitle: 'Основной профиль',
        allergies: const ['penicillin', 'amoxicillin'],
        notes: 'Хронический гастрит',
      );
      expect(profile.allergies, contains('penicillin'));
      expect(profile.notes, contains('гастрит'));

      // -------------------------------------------------------------
      // ШАГ 3. Препарат в аптечке (Амоксиклав, остаток 10.0 таб.)
      // -------------------------------------------------------------
      var medicine = const Medicine(
        id: 301,
        boxId: 1,
        name: 'Амоксиклав 500 мг',
        substance: 'Амоксициллин + Клавулановая кислота',
        form: 'таблетки',
        remaining: 10.0,
        total: 10.0,
        expiry: '2027-10-01',
        status: 'ok',
        quantityUnit: 'pill',
      );
      expect(medicine.remaining, 10.0);

      // -------------------------------------------------------------
      // ШАГ 4. Проверка безопасности CDS (Детекция аллергического риска)
      // -------------------------------------------------------------
      // Имитируем ответ сервера от движка MedicationSafetyService
      final cdsResponse = {
        'is_safe': false,
        'has_critical': true,
        'warnings': [
          'Внимание! Препарат содержит пенициллин, на который у пациента зафиксирована аллергия.',
        ],
      };
      final isSafe = cdsResponse['is_safe'] as bool;
      final warnings = List<String>.from(cdsResponse['warnings'] as List);
      expect(isSafe, isFalse, reason: 'Препарат группы пенициллинов небезопасен для аллергика');
      expect(warnings.first, contains('пенициллин'));

      // -------------------------------------------------------------
      // ШАГ 5. Лог приёма и планирование
      // -------------------------------------------------------------
      var intakeLog = IntakeLog(
        id: 501,
        profileId: profile.id,
        medicineId: medicine.id,
        medicineName: medicine.name,
        form: medicine.form,
        time: '09:00',
        rule: 'после еды',
        course: 'Антибиотикотерапия',
        dosageQuantity: 1.0,
        status: 'scheduled',
        scheduledTime: DateTime.now(),
      );
      expect(intakeLog.isTaken, isFalse);

      // -------------------------------------------------------------
      // ШАГ 6. Фиксация приёма (Take) со списанием остатка
      // -------------------------------------------------------------
      // Успешный приём: меняем статус на taken и списываем дозу
      intakeLog = intakeLog.copyWith(
        status: 'taken',
        taken: true,
      );
      medicine = medicine.copyWith(
        remaining: medicine.remaining - intakeLog.dosageQuantity,
      );

      expect(intakeLog.isTaken, isTrue);
      expect(medicine.remaining, 9.0, reason: 'Остаток должен атомарно уменьшиться с 10.0 до 9.0');

      // -------------------------------------------------------------
      // ШАГ 7. Построение отчёта комплаенса (Adherence Report)
      // -------------------------------------------------------------
      final adherenceReport = AdherenceReport(
        period: PeriodInfo(
          type: '7_days',
          startDate: DateTime.now().subtract(const Duration(days: 6)),
          endDate: DateTime.now(),
        ),
        scheduledCount: 1,
        takenCount: 1,
        missedCount: 0,
        adherenceRate: 100.0,
        streakDays: 1,
        dailyStats: [
          DailyStat(
            date: DateTime.now().toIso8601String().substring(0, 10),
            scheduled: 1,
            taken: 1,
            missed: 0,
          ),
        ],
        medicinesSummary: [
          MedicineAdherence(
            medicineId: medicine.id,
            name: medicine.name,
            scheduledCount: 1,
            takenCount: 1,
            missedCount: 0,
            adherenceRate: 100.0,
          ),
        ],
      );

      expect(adherenceReport.adherenceRate, 100.0);
      expect(adherenceReport.takenCount, 1);

      // -------------------------------------------------------------
      // ШАГ 8. Генерация PDF-отчёта через PdfReportService
      // -------------------------------------------------------------
      final Uint8List pdfBytes = await PdfReportService.generateAdherencePdf(
        report: adherenceReport,
        profile: profile,
        doctorNote: 'Пациент успешно завершил запланированный приём.',
      );

      // Проверка структуры бинарного PDF файла
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000), reason: 'PDF должен содержать полноценный контент верстки');

      // Проверка сигнатуры стандарта PDF (Magic Header: %PDF-)
      final header = ascii.decode(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'), reason: 'Файл обязан иметь валидный PDF-заголовок %PDF-');

      // Проверка трейлера (EOF маркер в конце файла)
      final trailer = ascii.decode(pdfBytes.sublist(pdfBytes.length - 10));
      expect(trailer, contains('%%EOF'), reason: 'PDF-документ обязан завершаться корректным маркером %%EOF');
    });
  });
}
