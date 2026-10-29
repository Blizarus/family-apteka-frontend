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
  final int? remaining;
  final int? medicineId;
  final DateTime? scheduledTime;

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
  });

  bool get isTaken => status == 'taken' || taken;
  bool get isSkipped => status == 'skipped';
  bool get isScheduled => status == 'scheduled' || (!isTaken && !isSkipped);

  DateTime get effectiveDate => scheduledTime ?? DateTime.now();

  bool matchesDate(DateTime date) {
    final d = effectiveDate;
    return d.year == date.year && d.month == date.month && d.day == date.day;
  }

  int get dosageQuantity {
    final match = RegExp(r'(\d+)\s*(таб|капс|доз|мл|кап)').firstMatch(rule);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 1;
    }
    return 1;
  }

  String get unit {
    final match = RegExp(r'\d+\s*(таб[а-я]*|капс[а-я]*|доз[а-я]*|мл|кап[а-я]*)').firstMatch(rule);
    if (match != null) {
      return match.group(1)!;
    }
    return form.isNotEmpty ? form.toLowerCase() : 'табл.';
  }

  factory IntakeLog.fromJson(Map<String, dynamic> json) {
    final intakeCourse = json['intake_course'] as Map<String, dynamic>?;
    final medicine = json['medicine'] as Map<String, dynamic>?;

    final profileId = (json['profileId'] ??
            json['profile_id'] ??
            intakeCourse?['profile_id'] as num?)
        ?.toInt() ??
        1;

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

    final isCurrent = json['isCurrent'] as bool? ??
        (!taken && rawStatus != 'skipped' && (time == '13:00' || time == '14:00'));

    final rawRemaining = json['remaining'] ?? medicine?['quantity'];
    final remaining = rawRemaining is num
        ? rawRemaining.toInt()
        : (double.tryParse(rawRemaining?.toString() ?? '') ?? 0).toInt();

    final medicineId = (json['medicine_id'] ??
            medicine?['id'] ??
            intakeCourse?['medicine_id'] as num?)
        ?.toInt();

    return IntakeLog(
      id: json['id'] as int,
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
      'remaining': remaining,
      'medicine_id': medicineId,
      'scheduled_time': scheduledTime?.toIso8601String(),
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
    int? remaining,
    int? medicineId,
    DateTime? scheduledTime,
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
    );
  }
}
