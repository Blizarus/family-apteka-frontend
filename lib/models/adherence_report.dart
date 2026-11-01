import '../utils/parse_helper.dart';

class PeriodInfo {
  final String type; // '7_days' | '30_days' | 'all'
  final DateTime startDate;
  final DateTime endDate;

  const PeriodInfo({
    required this.type,
    required this.startDate,
    required this.endDate,
  });

  factory PeriodInfo.fromJson(Map<String, dynamic> json) {
    return PeriodInfo(
      type: json['type'] as String? ?? '7_days',
      startDate: DateTime.tryParse(json['start_date'] as String? ?? '') ?? DateTime.now().subtract(const Duration(days: 6)),
      endDate: DateTime.tryParse(json['end_date'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'start_date': "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}",
      'end_date': "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}",
    };
  }
}

class DailyStat {
  final String date; // YYYY-MM-DD
  final int scheduled;
  final int taken;
  final int missed;

  const DailyStat({
    required this.date,
    required this.scheduled,
    required this.taken,
    required this.missed,
  });

  double get adherenceRate => scheduled > 0 ? (taken / scheduled) * 100 : 100.0;
  bool get isFullSuccess => scheduled > 0 && taken >= scheduled && missed == 0;
  bool get hasMissed => missed > 0;

  factory DailyStat.fromJson(Map<String, dynamic> json) {
    return DailyStat(
      date: json['date'] as String? ?? '',
      scheduled: ParseHelper.parseInt(json['scheduled']),
      taken: ParseHelper.parseInt(json['taken']),
      missed: ParseHelper.parseInt(json['missed']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'scheduled': scheduled,
      'taken': taken,
      'missed': missed,
    };
  }
}

class MedicineAdherence {
  final int medicineId;
  final String name;
  final int scheduledCount;
  final int takenCount;
  final int missedCount;
  final double adherenceRate;

  const MedicineAdherence({
    required this.medicineId,
    required this.name,
    required this.scheduledCount,
    required this.takenCount,
    required this.missedCount,
    required this.adherenceRate,
  });

  factory MedicineAdherence.fromJson(Map<String, dynamic> json) {
    return MedicineAdherence(
      medicineId: ParseHelper.parseInt(json['medicine_id'] ?? json['medicineId']),
      name: json['name'] as String? ?? 'Неизвестный препарат',
      scheduledCount: ParseHelper.parseInt(json['scheduled_count'] ?? json['scheduledCount']),
      takenCount: ParseHelper.parseInt(json['taken_count'] ?? json['takenCount']),
      missedCount: ParseHelper.parseInt(json['missed_count'] ?? json['missedCount']),
      adherenceRate: ParseHelper.parseDouble(json['adherence_rate'] ?? json['adherenceRate'], 100.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine_id': medicineId,
      'name': name,
      'scheduled_count': scheduledCount,
      'taken_count': takenCount,
      'missed_count': missedCount,
      'adherence_rate': adherenceRate,
    };
  }
}

class AdherenceReport {
  final PeriodInfo period;
  final int scheduledCount;
  final int takenCount;
  final int missedCount;
  final double adherenceRate;
  final int streakDays;
  final List<DailyStat> dailyStats;
  final List<MedicineAdherence> medicinesSummary;

  const AdherenceReport({
    required this.period,
    required this.scheduledCount,
    required this.takenCount,
    required this.missedCount,
    required this.adherenceRate,
    required this.streakDays,
    required this.dailyStats,
    required this.medicinesSummary,
  });

  /// Клиническая оценка уровня приверженности по стандартам ВОЗ:
  /// >= 80% — высокий комплаенс (клинически эффективный)
  /// 60%..79% — умеренный комплаенс (требуется контроль)
  /// < 60% — низкий комплаенс (риск неэффективности терапии)
  String get complianceLevelLabel {
    if (adherenceRate >= 80.0) return 'Высокий комплаенс';
    if (adherenceRate >= 60.0) return 'Умеренный комплаенс';
    return 'Низкий комплаенс';
  }

  factory AdherenceReport.fromJson(Map<String, dynamic> json) {
    return AdherenceReport(
      period: PeriodInfo.fromJson(json['period'] as Map<String, dynamic>? ?? {}),
      scheduledCount: ParseHelper.parseInt(json['scheduled_count'] ?? json['scheduledCount']),
      takenCount: ParseHelper.parseInt(json['taken_count'] ?? json['takenCount']),
      missedCount: ParseHelper.parseInt(json['missed_count'] ?? json['missedCount']),
      adherenceRate: ParseHelper.parseDouble(json['adherence_rate'] ?? json['adherenceRate'], 100.0),
      streakDays: ParseHelper.parseInt(json['streak_days'] ?? json['streakDays']),
      dailyStats: (json['daily_stats'] as List<dynamic>?)
              ?.map((e) => DailyStat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      medicinesSummary: (json['medicines_summary'] as List<dynamic>?)
              ?.map((e) => MedicineAdherence.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period.toJson(),
      'scheduled_count': scheduledCount,
      'taken_count': takenCount,
      'missed_count': missedCount,
      'adherence_rate': adherenceRate,
      'streak_days': streakDays,
      'daily_stats': dailyStats.map((e) => e.toJson()).toList(),
      'medicines_summary': medicinesSummary.map((e) => e.toJson()).toList(),
    };
  }
}
