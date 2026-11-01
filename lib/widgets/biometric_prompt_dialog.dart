import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';

/// Modal dialog / sheet prompting user for Touch ID / Face ID verification.
class BiometricPromptDialog extends StatefulWidget {
  final BiometricService? biometricService;
  final String title;
  final String localizedReason;
  final VoidCallback? onPasswordFallback;

  const BiometricPromptDialog({
    super.key,
    this.biometricService,
    this.title = 'Биометрическая защита',
    this.localizedReason = 'Приложите палец к сканеру Touch ID или используйте Face ID для быстрого доступа к данным аптечки',
    this.onPasswordFallback,
  });

  /// Displays the prompt as a centered modal dialog.
  static Future<bool?> show(
    BuildContext context, {
    BiometricService? biometricService,
    String? title,
    String? localizedReason,
    VoidCallback? onPasswordFallback,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BiometricPromptDialog(
        biometricService: biometricService,
        title: title ?? 'Биометрическая защита',
        localizedReason: localizedReason ??
            'Приложите палец к сканеру Touch ID или используйте Face ID для быстрого доступа к данным аптечки',
        onPasswordFallback: onPasswordFallback,
      ),
    );
  }

  /// Displays the prompt as a bottom sheet.
  static Future<bool?> showModal(
    BuildContext context, {
    BiometricService? biometricService,
    String? title,
    String? localizedReason,
    VoidCallback? onPasswordFallback,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BiometricPromptDialog(
        biometricService: biometricService,
        title: title ?? 'Биометрическая защита',
        localizedReason: localizedReason ??
            'Приложите палец к сканеру Touch ID или используйте Face ID для быстрого доступа к данным аптечки',
        onPasswordFallback: onPasswordFallback,
      ),
    );
  }

  @override
  State<BiometricPromptDialog> createState() => _BiometricPromptDialogState();
}

class _BiometricPromptDialogState extends State<BiometricPromptDialog> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  BiometricService _resolveService() {
    if (widget.biometricService != null) {
      return widget.biometricService!;
    }
    try {
      return context.read<ApiService>().biometricService;
    } catch (_) {
      return BiometricService();
    }
  }

  Future<void> _handleAuthenticate() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final service = _resolveService();
    final success = await service.authenticate(
      localizedReason: widget.localizedReason,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isAuthenticating = false;
        _errorMessage = 'Отпечаток не распознан. Попробуйте снова или войдите по паролю.';
      });
    }
  }

  void _handlePasswordFallback() {
    widget.onPasswordFallback?.call();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emerald circular icon container
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.statusOkBg,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFA7F3D0), width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2210B981),
                    blurRadius: 18,
                    spreadRadius: 3,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.fingerprint_rounded,
                  size: 50,
                  color: AppColors.statusOkDot,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Dialog Title
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Dialog Reason / Subtitle
            Text(
              widget.localizedReason,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),

            // Error display if failed
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                key: const Key('biometric_error_banner'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.statusExpiredBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.statusExpiredBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.statusExpiredText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        key: const Key('biometric_error_text'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.statusExpiredText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Confirm biometric button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                key: const Key('biometric_confirm_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isAuthenticating ? null : _handleAuthenticate,
                icon: _isAuthenticating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.fingerprint_rounded, size: 20),
                label: Text(
                  _isAuthenticating ? 'Проверка...' : 'Подтвердить отпечаток',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Fallback password button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                key: const Key('biometric_password_fallback_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _handlePasswordFallback,
                icon: const Icon(Icons.password_rounded, size: 18, color: AppColors.textMuted),
                label: const Text(
                  'Вход по паролю',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
