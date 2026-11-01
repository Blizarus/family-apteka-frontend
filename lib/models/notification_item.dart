class NotificationItem {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString() ?? 'general';

    String defaultTitle = 'Уведомление';
    String defaultMessage = 'Системное оповещение аптечки';

    switch (rawType) {
      case 'expiry_critical':
        defaultTitle = 'Критический срок годности';
        defaultMessage = 'Срок годности препарата истёк! Прекратите приём и утилизируйте остаток.';
        break;
      case 'expiry_warning_7d':
        defaultTitle = 'Срок годности (7 дней)';
        defaultMessage = 'Срок годности препарата истекает в течение 7 дней. Запланируйте обновление запаса.';
        break;
      case 'expiry_warning_30d':
        defaultTitle = 'Срок годности истекает';
        defaultMessage = 'Срок годности препарата истекает в течение 30 дней.';
        break;
      case 'opened_expired':
        defaultTitle = 'Истёк срок после вскрытия';
        defaultMessage = 'Период безопасного использования препарата после вскрытия истёк.';
        break;
      case 'low_stock':
        defaultTitle = 'Заканчивается запас';
        defaultMessage = 'Остаток препарата на исходе. Рекомендуется пополнить запас в аптечке.';
        break;
      case 'intake_reminder':
        defaultTitle = 'Напоминание о приёме';
        defaultMessage = 'Пришло время принять назначенное лекарство по вашему курсу.';
        break;
    }

    final title = (json['title'] as String?)?.trim().isNotEmpty == true
        ? json['title'] as String
        : defaultTitle;

    final message = (json['message'] as String?)?.trim().isNotEmpty == true
        ? json['message'] as String
        : defaultMessage;

    final isRead = (json['is_read'] as bool?) ??
        (json['isRead'] as bool?) ??
        false;

    final dateStr = json['created_at']?.toString() ??
        json['createdAt']?.toString() ??
        json['sent_at']?.toString() ??
        '';

    DateTime createdAt = DateTime.tryParse(dateStr) ?? DateTime.now();

    return NotificationItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: title,
      message: message,
      type: rawType,
      isRead: isRead,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationItem copyWith({
    int? id,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
