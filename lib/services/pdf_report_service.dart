import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/adherence_report.dart';
import '../models/profile.dart';

class PdfReportService {
  /// Генерация бинарных данных PDF-документа отчёта о комплаенсе для врача.
  static Future<Uint8List> generateAdherencePdf({
    required AdherenceReport report,
    required Profile? profile,
    String doctorNote = '',
    pw.Font? customFontRegular,
    pw.Font? customFontBold,
  }) async {
    final pdf = pw.Document(
      title: 'Клинический отчёт о комплаенсе — Семейная аптечка',
      author: 'Маркова И. Б. (ИС «Семейная аптечка»)',
    );

    pw.Font fontRegular;
    pw.Font fontBold;

    if (customFontRegular != null && customFontBold != null) {
      fontRegular = customFontRegular;
      fontBold = customFontBold;
    } else {
      try {
        fontRegular = await PdfGoogleFonts.robotoRegular();
        fontBold = await PdfGoogleFonts.robotoBold();
      } catch (e) {
        debugPrint('Failed to load Google Fonts, falling back to standard fonts: $e');
        fontRegular = pw.Font.helvetica();
        fontBold = pw.Font.helveticaBold();
      }
    }

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    final patientName = profile?.name ?? 'Не указан';
    final patientRole = profile?.role ?? 'Пациент';
    final allergies = (profile?.allergies.isNotEmpty ?? false)
        ? profile!.allergies.join(', ')
        : 'Не отягощен (аллергий не зафиксировано)';

    final startStr = _formatDate(report.period.startDate);
    final endStr = _formatDate(report.period.endDate);
    final nowStr = _formatDate(DateTime.now());

    final primaryColor = PdfColor.fromInt(0xFF0D9488); // Emerald #0D9488
    final lightTeal = PdfColor.fromInt(0xFFF0FDFA);
    final borderColor = PdfColor.fromInt(0xFFCBD5E1);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        theme: theme,
        header: (context) => _buildHeader(primaryColor, nowStr),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 12),
          // Заголовок
          pw.Center(
            child: pw.Text(
              'ОТЧЁТ О ПРИВЕРЖЕННОСТИ ФАРМАКОТЕРАПИИ (КОМПЛАЕНС)',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Center(
            child: pw.Text(
              'Для предоставления лечащему врачу • Мониторинг режима приёма лекарственных средств',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 14),

          // 1. Паспортные данные пациента
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderColor),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              color: lightTeal,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Пациент: $patientName ($patientRole)',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Период анализа: $startStr — $endStr',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text('Аллергологический анамнез: $allergies',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.red800)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // 2. Сводные метрики приверженности (KPI)
          pw.Row(
            children: [
              _buildKpiCard(
                'Общий комплаенс',
                '${report.adherenceRate}%',
                report.complianceLevelLabel,
                report.adherenceRate >= 80 ? PdfColors.green700 : (report.adherenceRate >= 60 ? PdfColors.orange700 : PdfColors.red700),
              ),
              pw.SizedBox(width: 8),
              _buildKpiCard('Назначено приёмов', '${report.scheduledCount}', 'за период', PdfColors.blueGrey800),
              pw.SizedBox(width: 8),
              _buildKpiCard('Принято вовремя', '${report.takenCount}', 'успешно', PdfColors.green800),
              pw.SizedBox(width: 8),
              _buildKpiCard('Пропущено', '${report.missedCount}', 'приёмов', PdfColors.red800),
              pw.SizedBox(width: 8),
              _buildKpiCard('Стрик дисциплины', '${report.streakDays} дн.', 'подряд', primaryColor),
            ],
          ),
          pw.SizedBox(height: 16),

          // 3. Статистика в разрезе препаратов
          pw.Text('1. Дисциплина по назначенным лекарственным препаратам',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 6),
          _buildMedicinesTable(report.medicinesSummary, borderColor),
          pw.SizedBox(height: 16),

          // 4. Посуточная динамика приёмов
          pw.Text('2. Посуточный журнал приёма препаратов',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 6),
          _buildDailyTable(report.dailyStats, borderColor),
          pw.SizedBox(height: 18),

          // 5. Блок врача
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderColor),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Заключение и рекомендации лечащего врача:',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(doctorNote.isNotEmpty ? doctorNote : '___________________________________________________________________________________________________________\n___________________________________________________________________________________________________________',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Врач: ____________________ / ____________________ /',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('М.П.', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Дата осмотра: «___» __________ 202_ г.',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(PdfColor primaryColor, String dateStr) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Text('ИС «Семейная аптечка»',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.Text(' • Модуль клинической безопасности и комплаенса',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
          pw.Text('Сформировано: $dateStr', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('ВКР Маркова И. Б. • 09.04.04 Программная инженерия • МГУ им. Н.П. Огарёва',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Стр. ${context.pageNumber} из ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiCard(String label, String value, String sub, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: PdfColors.white,
        ),
        child: pw.Column(
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
            pw.SizedBox(height: 1),
            pw.Text(sub, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildMedicinesTable(List<MedicineAdherence> items, PdfColor borderColor) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _th('Наименование препарата'),
            _th('Назначено'),
            _th('Принято'),
            _th('Пропущено'),
            _th('Комплаенс'),
          ],
        ),
        ...items.map((m) {
          final isGood = m.adherenceRate >= 80;
          return pw.TableRow(
            children: [
              _td(m.name, bold: true),
              _td('${m.scheduledCount}', align: pw.TextAlign.center),
              _td('${m.takenCount}', align: pw.TextAlign.center),
              _td('${m.missedCount}', align: pw.TextAlign.center, color: m.missedCount > 0 ? PdfColors.red800 : PdfColors.black),
              _td('${m.adherenceRate}%', align: pw.TextAlign.center, bold: true, color: isGood ? PdfColors.green800 : PdfColors.red800),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildDailyTable(List<DailyStat> stats, PdfColor borderColor) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _th('Дата'),
            _th('Назначено'),
            _th('Принято'),
            _th('Пропущено'),
            _th('Статус дня'),
          ],
        ),
        ...stats.map((d) {
          String status = 'Приёмов не было';
          PdfColor statusColor = PdfColors.grey600;
          if (d.scheduled > 0) {
            if (d.isFullSuccess) {
              status = '100% выполнено';
              statusColor = PdfColors.green800;
            } else if (d.hasMissed) {
              status = 'Есть пропуски';
              statusColor = PdfColors.red800;
            } else {
              status = 'Частично';
              statusColor = PdfColors.orange800;
            }
          }
          return pw.TableRow(
            children: [
              _td(d.date, align: pw.TextAlign.center),
              _td('${d.scheduled}', align: pw.TextAlign.center),
              _td('${d.taken}', align: pw.TextAlign.center),
              _td('${d.missed}', align: pw.TextAlign.center, color: d.missed > 0 ? PdfColors.red800 : PdfColors.black),
              _td(status, align: pw.TextAlign.center, bold: true, color: statusColor),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _th(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
    );
  }

  static pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left, bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? PdfColors.black),
        textAlign: align,
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}
