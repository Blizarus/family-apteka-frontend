import '../utils/parse_helper.dart';

class IntakeLog {
  final int id;
  final int profileId;
  final String medicineName;
  final String form;
  final String time;
  final String rule;
  final bool taken;
  final String status; // 'scheduled' | 'taken' | 'skipped'
  final String? skippedReason;
  final String course;
  final bool isCurrent;
  final double? remaining;
  final int? medicineId;
  final DateTime? scheduledTime;
  final double? quantityTaken;
  final double dosageQuantity;

  const IntakeLog({
    required this.id,
    required this.profileId,
    required this.medicineName,
    required this.form,
    required this.time,
    required this.rule,
    this.taken = false,
    this.status = 'scheduled',
    this.skippedReason,
    required this.course,
    this.isCurrent = false,
    this.remaining,
    this.medicineId,
    this.scheduledTime,
    this.quantityTaken,
    this.dosageQuantity = 1.0,
  });

  bool get isTaken => status == 'taken' || taken;
  bool get isSkipped => status == 'skipped';
  bool get isScheduled => status == 'scheduled' || (!isTaken && !isSkipped);

  DateTime get effectiveDate => scheduledTime ?? DateTime.now();

  bool matchesDate(DateTime date) {
    final d = effectiveDate;
    return d.year == date.year && d.month == date.month && d.day == date.day;
  }

  static double parseDosageFromRule(String rule) {
    final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*(таб|капс|доз|мл|кап)').firstMatch(rule);
    if (match != null) {
      final s = match.group(1)!.replaceAll(',', '.');
      return double.tryParse(s) ?? 1.0;
    }
    return 1.0;
  }

  String get unit {
    final match = RegExp(r'\d+(?:[.,]\d+)?\s*(таб[а-я]*|капс[а-я]*|доз[а-я]*|мл|кап[а-я]*)').firstMatch(rule);
    if (match != null) {
      return match.group(1)!;
    }
    return form.isNotEmpty ? form.toLowerCase() : 'табл.';
  }

  factory IntakeLog.fromJson(Map<String, dynamic> json, {DateTime? currentTime}) {
    final intakeCourse = json['intake_course'] as Map<String, dynamic>?;
    final medicine = json['medicine'] as Map<String, dynamic>?;

    final profileId = ParseHelper.parseInt(
      json['profileId'] ?? json['profile_id'] ?? intakeCourse?['profile_id'],
      1,
    );

    final medicineName = json['medicineName'] as String? ??
        medicine?['custom_trade_name'] as String? ??
        intakeCourse?['medicine']?['custom_trade_name'] as String? ??
        'Лекарство';

    final form = json['form'] as String? ??
        medicine?['quantity_unit'] as String? ??
        'Таблетки';

    // Time formatting from scheduled_time or time
    String time = json['time'] as String? ?? '';
    DateTime? parsedDate;
    final rawScheduled = json['scheduled_time']?.toString();
    if (rawScheduled != null) {
      try {
        parsedDate = DateTime.parse(rawScheduled).toLocal();
        final h = parsedDate.hour.toString().padLeft(2, '0');
        final m = parsedDate.minute.toString().padLeft(2, '0');
        time = '$h:$m';
      } catch (_) {
        if (rawScheduled.length >= 16) {
          time = rawScheduled.substring(11, 16);
        }
      }
    }
    if (time.isEmpty) time = '12:00';

    final rule = json['rule'] as String? ??
        intakeCourse?['dosage_instruction'] as String? ??
        'По назначению врача';

    final rawStatus = json['status']?.toString() ?? 'scheduled';
    final taken = json['taken'] as bool? ?? (rawStatus == 'taken');
    final skippedReason = json['skipped_reason'] as String? ?? json['skippedReason'] as String?;

    final course = json['course'] as String? ??
        intakeCourse?['title'] as String? ??
        'Назначенный курс';

    // Dynamic isCurrent calculation (DEF-07, CWE-547)
    final bool? explicitCurrent = (json['isCurrent'] ?? json['is_current']) as bool?;
    final now = currentTime ?? DateTime.now();

    bool computedIsCurrent = false;
    if (!taken && rawStatus != 'skipped') {
      DateTime? target = parsedDate;
      if (target == null && time.isNotEmpty) {
        final parts = time.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null) {
            target = DateTime(now.year, now.month, now.day, h, m);
          }
        }
      }
      if (target != null) {
        // Окно актуальности: прием назначен на сегодня и находится в интервале
        // от -60 минут (за 1 час до приема) до +120 минут (просрочен до 2 часов)
        final isSameDay = target.year == now.year && target.month == now.month && target.day == now.day;
        final diffMinutes = now.difference(target).inMinutes;
        computedIsCurrent = isSameDay && (diffMinutes >= -60 && diffMinutes <= 120);
      }
    }
    final isCurrent = explicitCurrent ?? computedIsCurrent;

    final rawRemaining = json['remaining'] ?? medicine?['quantity'];
    final remaining = ParseHelper.parseNullableDouble(rawRemaining);

    final medicineId = ParseHelper.parseNullableInt(
      json['medicine_id'] ?? medicine?['id'] ?? intakeCourse?['medicine_id'],
    );

    final quantityTaken = ParseHelper.parseNullableDouble(
      json['quantity_taken'] ?? json['quantityTaken'],
    );

    final dosageQuantity = ParseHelper.parseDouble(
      json['dosage_quantity'] ?? json['dosageQuantity'] ?? intakeCourse?['dosage_quantity'],
      parseDosageFromRule(rule),
    );

    return IntakeLog(
      id: ParseHelper.parseInt(json['id']),
      profileId: profileId,
      medicineName: medicineName,
      form: form,
      time: time,
      rule: rule,
      taken: taken,
      status: rawStatus,
      skippedReason: skippedReason,
      course: course,
      isCurrent: isCurrent,
      remaining: remaining,
      medicineId: medicineId,
      scheduledTime: parsedDate,
      quantityTaken: quantityTaken,
      dosageQuantity: dosageQuantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'medicineName': medicineName,
      'form': form,
      'time': time,
      'rule': rule,
      'taken': taken,
      'status': status,
      'skipped_reason': skippedReason,
      'course': course,
      'isCurrent': isCurrent,
      'is_current': isCurrent,
      'remaining': remaining,
      'medicine_id': medicineId,
      'scheduled_time': scheduledTime?.toIso8601String(),
      'quantity_taken': quantityTaken,
      'dosage_quantity': dosageQuantity,
    };
  }

  IntakeLog copyWith({
    int? id,
    int? profileId,
    String? medicineName,
    String? form,
    String? time,
    String? rule,
    bool? taken,
    String? status,
    String? skippedReason,
    String? course,
    bool? isCurrent,
    double? remaining,
    int? medicineId,
    DateTime? scheduledTime,
    double? quantityTaken,
    double? dosageQuantity,
  }) {
    return IntakeLog(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      medicineName: medicineName ?? this.medicineName,
      form: form ?? this.form,
      time: time ?? this.time,
      rule: rule ?? this.rule,
      taken: taken ?? this.taken,
      status: status ?? this.status,
      skippedReason: skippedReason ?? this.skippedReason,
      course: course ?? this.course,
      isCurrent: isCurrent ?? this.isCurrent,
      remaining: remaining ?? this.remaining,
      medicineId: medicineId ?? this.medicineId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      quantityTaken: quantityTaken ?? this.quantityTaken,
      dosageQuantity: dosageQuantity ?? this.dosageQuantity,
    );
  }
}
