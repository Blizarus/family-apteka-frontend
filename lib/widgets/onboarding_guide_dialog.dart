import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class OnboardingGuideDialog extends StatefulWidget {
  final StorageService? storageService;

  const OnboardingGuideDialog({
    super.key,
    this.storageService,
  });

  static Future<void> show(
    BuildContext context, {
    StorageService? storageService,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OnboardingGuideDialog(storageService: storageService),
    );
  }

  @override
  State<OnboardingGuideDialog> createState() => _OnboardingGuideDialogState();
}

class _OnboardingGuideDialogState extends State<OnboardingGuideDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingCardData> _cards = const [
    _OnboardingCardData(
      icon: '🛡️',
      badge: '152-ФЗ РФ · AES-256 · Argon2id',
      badgeColor: Color(0xFFE0F2FE),
      badgeTextColor: Color(0xFF0369A1),
      title: 'Защищенное хранение данных семьи',
      subtitle: 'Медицинская тайна и защита 152-ФЗ',
      description:
          'Все персональные и медицинские данные (диагнозы, аллергии, назначения) шифруются по стандарту AES-256 GCM. База данных расположена в РФ (ст. 18 152-ФЗ), а пароли хэшируются алгоритмом Argon2id.',
      bulletPoints: [
        'Сквозное шифрование специальных категорий ПДн',
        'Персональная изоляция медицинских профилей семьи',
        'Строго нулевая передача третьим лицам или рекламе',
      ],
    ),
    _OnboardingCardData(
      icon: '⏳',
      badge: 'FEFO-Opened · Контроль вскрытия',
      badgeColor: Color(0xFFFEF3C7),
      badgeTextColor: Color(0xFFB45309),
      title: 'Умный контроль сроков годности и вскрытых упаковок',
      subtitle: 'Интеллектуальная ротация FEFO-Opened',
      description:
          'Многие капли, мази и сиропы после первого вскрытия хранятся всего несколько недель. Алгоритм FEFO-Opened автоматически вычисляет реальную годность и защищает семью светофорными алертами.',
      bulletPoints: [
        'Учёт сокращённого срока хранения после вскрытия',
        'Светофорные статусы безопасности (зелёный/жёлтый/красный)',
        'Авто-добавление в список покупок при исчерпании остатка',
      ],
    ),
    _OnboardingCardData(
      icon: '🧬',
      badge: 'CDS-движок · ГРЛС Минздрава',
      badgeColor: Color(0xFFCCFBF1),
      badgeTextColor: Color(0xFF0F766E),
      title: 'Контроль совместимости и аллергий',
      subtitle: 'Клиническая система поддержки решений (CDS)',
      description:
          'Интеллектуальный CDS-модуль сопоставляет назначаемые препараты с индивидуальным профилем аллергий членов семьи и базой опасных взаимодействий справочника ГРЛС в режиме реального времени.',
      bulletPoints: [
        'Мгновенный перехват опасных лекарственных комбинаций',
        'Персональный кросс-контроль аллергий для каждого профиля',
        'Интеграция с официальным эталонным каталогом ГРЛС',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    StorageService? storage = widget.storageService;
    if (storage == null && mounted) {
      try {
        storage = context.read<ApiService>().storageService;
      } catch (_) {}
    }

    if (storage != null) {
      await storage.setOnboardingCompleted(true);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _nextPage() {
    if (_currentPage < _cards.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with step badge & close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryBorderLight),
                      ),
                      child: Text(
                        'Знакомство · Шаг ${_currentPage + 1} из ${_cards.length}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryHover,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // PageView Content
              SizedBox(
                height: 380,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _cards.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final card = _cards[index];
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Icon container
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: card.badgeColor,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(card.icon, style: const TextStyle(fontSize: 32)),
                          ),
                          const SizedBox(height: 12),

                          // Tech Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: card.badgeColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              card.badge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: card.badgeTextColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Title
                          Text(
                            card.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Subtitle
                          Text(
                            card.subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryHover,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Description
                          Text(
                            card.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Bullets
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: card.bulletPoints.map((bp) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          bp,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Page Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_cards.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                children: [
                  if (_currentPage < _cards.length - 1) ...[
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          key: const Key('onboarding_skip_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _completeOnboarding,
                          child: const Text('Пропустить', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          key: const Key('onboarding_next_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _nextPage,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Далее', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          key: const Key('onboarding_finish_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _completeOnboarding,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Начать использование', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingCardData {
  final String icon;
  final String badge;
  final Color badgeColor;
  final Color badgeTextColor;
  final String title;
  final String subtitle;
  final String description;
  final List<String> bulletPoints;

  const _OnboardingCardData({
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.bulletPoints,
  });
}
