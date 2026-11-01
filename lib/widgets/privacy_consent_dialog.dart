import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class PrivacyConsentDialog extends StatefulWidget {
  final StorageService? storageService;
  final bool isDismissible;
  final bool initialMandatory;
  final bool initialCloudSync;
  final void Function(bool accepted, bool cloudSync)? onConsentSubmitted;

  const PrivacyConsentDialog({
    super.key,
    this.storageService,
    this.isDismissible = true,
    this.initialMandatory = false,
    this.initialCloudSync = true,
    this.onConsentSubmitted,
  });

  static Future<bool?> show(
    BuildContext context, {
    StorageService? storageService,
    bool isDismissible = true,
    bool initialMandatory = false,
    bool initialCloudSync = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (ctx) => PrivacyConsentDialog(
        storageService: storageService,
        isDismissible: isDismissible,
        initialMandatory: initialMandatory,
        initialCloudSync: initialCloudSync,
      ),
    );
  }

  @override
  State<PrivacyConsentDialog> createState() => _PrivacyConsentDialogState();
}

class _PrivacyConsentDialogState extends State<PrivacyConsentDialog> {
  late bool _mandatoryConsent;
  late bool _cloudSyncConsent;
  bool _isExpandedLegal = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _mandatoryConsent = widget.initialMandatory;
    _cloudSyncConsent = widget.initialCloudSync;
    _loadExistingConsent();
  }

  Future<void> _loadExistingConsent() async {
    final storage = widget.storageService ??
        (mounted ? context.read<ApiService>().storageService : null);
    if (storage != null) {
      final accepted = await storage.isPrivacyConsentAccepted();
      final cloud = await storage.isPrivacyConsentCloudSync();
      if (mounted && accepted) {
        setState(() {
          _mandatoryConsent = true;
          _cloudSyncConsent = cloud;
        });
      }
    }
  }

  Future<void> _handleAccept() async {
    if (!_mandatoryConsent) return;

    setState(() => _isSaving = true);

    StorageService? storage = widget.storageService;
    if (storage == null && mounted) {
      try {
        storage = context.read<ApiService>().storageService;
      } catch (_) {}
    }

    if (storage != null) {
      await storage.savePrivacyConsent(
        accepted: true,
        cloudSync: _cloudSyncConsent,
        version: 'v1.0-2026',
        date: DateTime.now().toIso8601String(),
      );
    }

    widget.onConsentSubmitted?.call(true, _cloudSyncConsent);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop(true);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🛡️', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Согласие на обработку ПДн',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '152-ФЗ РФ · Медицинские категории',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isDismissible)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              // Category notice
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF16A34A)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'В соответствии со ст. 10 152-ФЗ обработка медицинских категорий (диагнозы, аллергии, назначения) осуществляется только с вашего согласия.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF166534),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Expandable Legal Curtain (Меры защиты и правовые основания)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _isExpandedLegal = !_isExpandedLegal),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.gavel_rounded, size: 16, color: AppColors.primaryHover),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Меры защиты и правовые основания',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        _isExpandedLegal ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              if (_isExpandedLegal) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SecurityBullet(
                        icon: Icons.lock_outline_rounded,
                        title: 'Криптографическая защита (AES-256 GCM):',
                        description:
                            'Локальные данные профилей семьи и лекарств защищены современными шифроалгоритмами по ГОСТ / AES-256.',
                      ),
                      SizedBox(height: 6),
                      _SecurityBullet(
                        icon: Icons.key_rounded,
                        title: 'Хэширование паролей Argon2id:',
                        description:
                            'Учетные данные пользователей защищены необратимым хэшированием с индивидуальной криптографической солью.',
                      ),
                      SizedBox(height: 6),
                      _SecurityBullet(
                        icon: Icons.dns_outlined,
                        title: 'Локализация в РФ (ст. 18 152-ФЗ):',
                        description:
                            'Все персональные и медицинские сведения обрабатываются и хранятся на серверах в защищенных ЦОД РФ.',
                      ),
                      SizedBox(height: 6),
                      _SecurityBullet(
                        icon: Icons.block_flipped,
                        title: 'Отсутствие передачи третьим лицам:',
                        description:
                            'Данные никогда не передаются и не продаются рекламным сетям или коммерческим брокерам.',
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Mandatory Checkbox
              Material(
                color: _mandatoryConsent ? AppColors.primarySurface : const Color(0xFFFFF1F2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _mandatoryConsent ? AppColors.primaryBorder : const Color(0xFFFECDD3),
                  ),
                ),
                child: CheckboxListTile(
                  key: const Key('privacy_mandatory_checkbox'),
                  value: _mandatoryConsent,
                  onChanged: (val) {
                    setState(() => _mandatoryConsent = val ?? false);
                  },
                  activeColor: AppColors.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Согласен на локальную обработку медицинских данных (аллергии, назначения, приём лекарств)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _mandatoryConsent ? AppColors.primaryDeep : const Color(0xFF9F1239),
                            height: 1.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _mandatoryConsent
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : const Color(0xFFFDA4AF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Обязательно',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _mandatoryConsent ? AppColors.primaryDeep : const Color(0xFF881337),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Необходимо для составления графика приёма и CDS-контроля совместимости лекарств',
                      style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Optional Cloud Sync Checkbox
              Material(
                color: _cloudSyncConsent ? AppColors.surfaceSubtle : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: CheckboxListTile(
                  key: const Key('privacy_cloud_checkbox'),
                  value: _cloudSyncConsent,
                  onChanged: (val) {
                    setState(() => _cloudSyncConsent = val ?? false);
                  },
                  activeColor: AppColors.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Разрешаю облачную синхронизацию и семейный доступ к аптечке',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Опционально',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Синхронизация между устройствами семьи по зашифрованному каналу TLS 1.3',
                      style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Version / Regulatory stamp
              const Center(
                child: Text(
                  'Версия документа: v1.0-2026 · Редакция от 01.01.2026',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  if (widget.isDismissible) ...[
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          key: const Key('privacy_cancel_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Отмена', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        key: const Key('privacy_accept_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _mandatoryConsent ? AppColors.primary : const Color(0xFFCBD5E1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (_mandatoryConsent && !_isSaving) ? _handleAccept : null,
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Принять и продолжить',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SecurityBullet({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.primaryHover),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
              children: [
                TextSpan(
                  text: '$title ',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
