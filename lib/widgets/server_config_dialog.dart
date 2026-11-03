import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'toast_helper.dart';

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    if (kReleaseMode) {
      return Future.value();
    }
    return showDialog<void>(
      context: context,
      builder: (ctx) => const ServerConfigDialog(),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _urlController;
  bool _isChecking = false;
  String? _statusMessage;
  bool _isSuccess = false;
  late bool _isMockMode;

  @override
  void initState() {
    super.initState();
    final apiService = context.read<ApiService>();
    _urlController = TextEditingController(text: apiService.baseUrl);
    _isMockMode = apiService.isMockMode;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testAndSave([bool forceSave = false]) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    if (forceSave) {
      final apiService = context.read<ApiService>();
      await apiService.updateBaseUrl(url);
      if (mounted) {
        Navigator.of(context).pop();
        ToastHelper.show(
          context,
          message: 'Адрес сервера сохранён: $url',
          icon: '🌐',
        );
      }
      return;
    }

    setState(() {
      _isChecking = true;
      _statusMessage = null;
      _isSuccess = false;
    });

    final apiService = context.read<ApiService>();
    final isAlive = await apiService.checkConnection(url);

    if (!mounted) return;

    if (isAlive) {
      await apiService.updateBaseUrl(url);
      setState(() {
        _isChecking = false;
        _isSuccess = true;
        _statusMessage = 'Связь успешно установлена (200 OK)';
      });

      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        Navigator.of(context).pop();
        ToastHelper.show(
          context,
          message: 'Подключено к серверу: $url',
          icon: '✅',
        );
      }
    } else {
      setState(() {
        _isChecking = false;
        _isSuccess = false;
        _statusMessage = 'Сервер недоступен. Проверьте IP, порт или запустите php artisan serve';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.5);
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.7);

    return AlertDialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: semantic.infoBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline),
            ),
            child: Icon(
              Icons.dns_rounded,
              color: cs.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Адрес сервера API',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Настройки подключения для тестеров',
                  style: TextStyle(
                    fontSize: 11,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                'БАЗОВЫЙ URL API REST',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _urlController,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'http://127.0.0.1:8000/api',
                  hintStyle: TextStyle(fontSize: 12, color: textMuted),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Presets
              Text(
                'БЫСТРЫЕ ШАБЛОНЫ:',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('☁️ Production (SpaceWeb)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    backgroundColor: cs.primaryContainer,
                    side: BorderSide(color: cs.outline),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () {
                      _urlController.text = 'http://e340043kek.temp.swtest.ru/api';
                    },
                  ),
                  ActionChip(
                    label: const Text('🐳 Staging (Docker :8080)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    backgroundColor: cs.surfaceContainerHighest,
                    side: BorderSide(color: cs.outlineVariant),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () {
                      _urlController.text = 'http://127.0.0.1:8080/api';
                    },
                  ),
                  ActionChip(
                    label: const Text('💻 Local (Artisan :8000)', style: TextStyle(fontSize: 10)),
                    backgroundColor: cs.surfaceContainerHighest,
                    side: BorderSide(color: cs.outlineVariant),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () {
                      _urlController.text = 'http://127.0.0.1:8000/api';
                    },
                  ),
                  ActionChip(
                    label: const Text('📱 Android Emulator (10.0.2.2)', style: TextStyle(fontSize: 10)),
                    backgroundColor: cs.surfaceContainerHighest,
                    side: BorderSide(color: cs.outlineVariant),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () {
                      _urlController.text = 'http://10.0.2.2:8000/api';
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Demo mode switch for offline testing
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Демо-режим (без сети)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Автономная работа с локальными данными',
                            style: TextStyle(fontSize: 10, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _isMockMode,
                      activeTrackColor: cs.primary,
                      onChanged: (val) {
                        setState(() => _isMockMode = val);
                        context.read<ApiService>().isMockMode = val;
                      },
                    ),
                  ],
                ),
              ),

              // Status indicator
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isSuccess ? semantic.successBg : semantic.dangerBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isSuccess ? semantic.successBorder : semantic.dangerBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        size: 16,
                        color: _isSuccess ? semantic.success : semantic.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _isSuccess ? semantic.successText : semantic.dangerText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isChecking ? null : () => Navigator.of(context).pop(),
          child: Text('Отмена', style: TextStyle(color: textMuted)),
        ),
        if (!_isSuccess && _statusMessage != null)
          TextButton(
            onPressed: _isChecking ? null : () => _testAndSave(true),
            child: Text('Сохранить всё равно', style: TextStyle(color: textSecondary)),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onPressed: _isChecking ? null : () => _testAndSave(false),
          child: _isChecking
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                )
              : const Text('Сохранить и проверить связь', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
