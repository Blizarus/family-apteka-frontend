import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'toast_helper.dart';

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
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
    return AlertDialog(
      backgroundColor: Colors.white,
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
              color: AppColors.statusInfoBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: const Icon(
              Icons.dns_rounded,
              color: AppColors.primaryHover,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Адрес сервера API',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Настройки подключения для тестеров',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
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
              const Text(
                'БАЗОВЫЙ URL API REST',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _urlController,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'http://127.0.0.1:8000/api',
                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceSubtle,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Presets
              const Text(
                'БЫСТРЫЕ ШАБЛОНЫ:',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('☁️ swtest.ru (основной)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    backgroundColor: AppColors.primarySurface,
                    side: const BorderSide(color: AppColors.primaryBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () {
                      _urlController.text = 'http://e340043kek.temp.swtest.ru/api';
                    },
                  ),
                  ActionChip(
                    label: const Text('🌐 bluzaus.swtest.ru (зеркало)', style: TextStyle(fontSize: 10)),
                    backgroundColor: AppColors.surfaceSubtle,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () {
                      _urlController.text = 'http://bluzaus.ru.swtest.ru/api';
                    },
                  ),
                  ActionChip(
                    label: const Text('10.0.2.2 (Android Эмулятор)', style: TextStyle(fontSize: 10)),
                    backgroundColor: AppColors.surfaceSubtle,
                    side: const BorderSide(color: AppColors.border),
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
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Демо-режим (без сети)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Автономная работа с локальными данными',
                            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _isMockMode,
                      activeTrackColor: AppColors.primary,
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
                    color: _isSuccess ? AppColors.statusOkBg : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isSuccess ? AppColors.statusOkDot.withValues(alpha: 0.3) : const Color(0xFFFECDD3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        size: 16,
                        color: _isSuccess ? AppColors.statusOkText : const Color(0xFF9F1239),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _isSuccess ? AppColors.statusOkText : const Color(0xFF9F1239),
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
          child: const Text('Отмена', style: TextStyle(color: AppColors.textMuted)),
        ),
        if (!_isSuccess && _statusMessage != null)
          TextButton(
            onPressed: _isChecking ? null : () => _testAndSave(true),
            child: const Text('Сохранить всё равно', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onPressed: _isChecking ? null : () => _testAndSave(false),
          child: _isChecking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Сохранить и проверить связь', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
