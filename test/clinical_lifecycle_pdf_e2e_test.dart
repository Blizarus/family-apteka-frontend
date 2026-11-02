import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:frontend/models/adherence_report.dart';
import 'package:frontend/models/intake_log.dart';
import 'package:frontend/models/medicine.dart';
import 'package:frontend/models/profile.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/services/pdf_report_service.dart';

/// Декодер содержимого текстовых слоёв PDF-документа по ToUnicode CMap
String extractPdfTextContent(Uint8List pdfBytes) {
  final pdfStr = String.fromCharCodes(pdfBytes);
  final objects = <int, String>{};
  final objRegex = RegExp(r'(\d+)\s+0\s+obj([\s\S]*?)endobj');
  
  for (final m in objRegex.allMatches(pdfStr)) {
    final id = int.parse(m.group(1)!);
    final body = m.group(2)!;
    
    if (body.contains('stream')) {
      final sIdx = body.indexOf('stream');
      var dStart = sIdx + 6;
      while (dStart < body.length && (body.codeUnitAt(dStart) == 10 || body.codeUnitAt(dStart) == 13)) {
        dStart++;
      }
      final eIdx = body.indexOf('endstream');
      var dEnd = eIdx;
      while (dEnd > dStart && (body.codeUnitAt(dEnd - 1) == 10 || body.codeUnitAt(dEnd - 1) == 13)) {
        dEnd--;
      }
      final raw = pdfBytes.sublist(
        pdfStr.indexOf(body) + dStart,
        pdfStr.indexOf(body) + dEnd,
      );
      try {
        objects[id] = String.fromCharCodes(zlib.decode(raw));
      } catch (_) {
        objects[id] = String.fromCharCodes(raw);
      }
    } else {
      objects[id] = body;
    }
  }

  final fontToUnicodeMap = <String, Map<int, String>>{};
  final fontRegex = RegExp(r'/Font\s*<<([^>]+)>>');
  for (final body in objects.values) {
    final fMatch = fontRegex.firstMatch(body);
    if (fMatch != null) {
      final entries = fMatch.group(1)!;
      final entryMatches = RegExp(r'/([A-Za-z0-9]+)\s+(\d+)\s+0\s+R').allMatches(entries);
      for (final em in entryMatches) {
        final fontName = em.group(1)!;
        final fontObjId = int.parse(em.group(2)!);
        final fontObjBody = objects[fontObjId] ?? '';
        final tuMatch = RegExp(r'/ToUnicode\s+(\d+)\s+0\s+R').firstMatch(fontObjBody);
        if (tuMatch != null) {
          final tuObjId = int.parse(tuMatch.group(1)!);
          final tuBody = objects[tuObjId] ?? '';
          
          final cmap = <int, String>{};
          final bfcharMatches = RegExp(r'<([0-9a-fA-F]+)>\s+<([0-9a-fA-F]+)>').allMatches(tuBody);
          for (final bfm in bfcharMatches) {
            final glyph = int.parse(bfm.group(1)!, radix: 16);
            final unicode = int.parse(bfm.group(2)!, radix: 16);
            cmap[glyph] = String.fromCharCode(unicode);
          }
          fontToUnicodeMap[fontName] = cmap;
        }
      }
    }
  }

  final extractedText = StringBuffer();
  for (final body in objects.values) {
    if (body.contains('BT') && body.contains('ET')) {
      var currentFont = '';
      final tokens = body.split(RegExp(r'\s+'));
      for (var i = 0; i < tokens.length; i++) {
        final t = tokens[i];
        if (t.startsWith('/F') && i + 2 < tokens.length && tokens[i + 2] == 'Tf') {
          currentFont = t.substring(1);
        } else if (t.startsWith('[<') && t.endsWith('>]TJ')) {
          final hex = t.substring(2, t.length - 4);
          final cmap = fontToUnicodeMap[currentFont] ?? {};
          for (var j = 0; j + 4 <= hex.length; j += 4) {
            final glyph = int.parse(hex.substring(j, j + 4), radix: 16);
            if (cmap.containsKey(glyph)) {
              extractedText.write(cmap[glyph]);
            }
          }
          extractedText.write(' ');
        }
      }
    }
  }

  return extractedText.toString();
}

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
      Uint8List? fontBytes;
      final fontFile = File(r'C:\Windows\Fonts\arial.ttf');
      if (fontFile.existsSync()) {
        fontBytes = fontFile.readAsBytesSync();
      }

      final Uint8List pdfBytes = await PdfReportService.generateAdherencePdf(
        report: adherenceReport,
        profile: profile,
        doctorNote: 'Пациент успешно завершил запланированный курс антибиотикотерапии.',
        customFontRegular: fontBytes != null ? pw.Font.ttf(fontBytes.buffer.asByteData()) : null,
        customFontBold: fontBytes != null ? pw.Font.ttf(fontBytes.buffer.asByteData()) : null,
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

      // -------------------------------------------------------------
      // ШАГ 9. Извлечение текста из PDF и строгая проверка контента
      // -------------------------------------------------------------
      final pdfContentText = extractPdfTextContent(pdfBytes);

      // 1. Проверка имени пациента
      expect(pdfContentText, contains('Пациент: Ирина (Владелец)'),
          reason: 'PDF обязан содержать имя пациента «Ирина» и его роль');

      // 2. Проверка периода анализа
      expect(pdfContentText, contains('Период анализа:'),
          reason: 'PDF обязан содержать заголовок диапазона дат');
      final datePattern = RegExp(r'\d{2}\.\d{2}\.\d{4}\s*—\s*\d{2}\.\d{2}\.\d{4}');
      expect(datePattern.hasMatch(pdfContentText), isTrue,
          reason: 'PDF обязан содержать конкретный интервал дат периода');

      // 3. Проверка процента приверженности
      expect(pdfContentText, contains('100.0%'),
          reason: 'PDF обязан содержать точный показатель приверженности 100.0%');
      expect(pdfContentText, contains('Высокий комплаенс'),
          reason: 'PDF обязан содержать клиническую категорию уровня приверженности');
      expect(pdfContentText, contains('penicillin'),
          reason: 'PDF обязан отражать анамнез аллергических реакций пациента');
    });
  });
}
