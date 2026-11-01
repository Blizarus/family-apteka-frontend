import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/toast_helper.dart';
import '../widgets/privacy_consent_dialog.dart';
import '../widgets/onboarding_guide_dialog.dart';
import 'admin_panel_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final BiometricService? biometricService;

  const SettingsScreen({
    super.key,
    this.biometricService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _serverUrlController;
  bool _isCheckingConnection = false;
  String? _connectionStatus;
  bool? _connectionSuccess;
  bool _isConsentAccepted = false;
  String? _consentDate;
  String? _consentVersion;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    final apiService = context.read<ApiService>();
    _serverUrlController = TextEditingController(text: apiService.baseUrl);
    _loadConsentStatus();
    _loadBiometricStatus();
  }

  BiometricService _getBiometricService() {
    if (widget.biometricService != null) {
      return widget.biometricService!;
    }
    try {
      return context.read<ApiService>().biometricService;
    } catch (_) {
      return BiometricService();
    }
  }

  Future<void> _loadBiometricStatus() async {
    final bioService = _getBiometricService();
    final enabled = await bioService.isBiometricAuthEnabled();
    if (mounted) {
      setState(() {
        _isBiometricEnabled = enabled;
      });
    }
  }

  Future<void> _loadConsentStatus() async {
    final storage = context.read<ApiService>().storageService;
    final accepted = await storage.isPrivacyConsentAccepted();
    final date = await storage.getPrivacyConsentDate();
    final version = await storage.getPrivacyConsentVersion();
    if (mounted) {
      setState(() {
        _isConsentAccepted = accepted;
        _consentDate = date;
        _consentVersion = version;
      });
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime(AppState state, String type, TimeOfDay current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      state.updateDefaultTime(type, picked);
      ToastHelper.show(
        context,
        message: 'Время обновлено: ${_formatTimeOfDay(picked)}',
        icon: '⏰',
      );
    }
  }

  Future<void> _checkServerConnection(ApiService apiService) async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isCheckingConnection = true;
      _connectionStatus = null;
      _connectionSuccess = null;
    });

    final isAlive = await apiService.checkConnection(url);

    if (!mounted) return;

    setState(() {
      _isCheckingConnection = false;
      _connectionSuccess = isAlive;
      _connectionStatus = isAlive
          ? 'Связь успешно установлена (200 OK)'
          : 'Сервер недоступен. Проверьте адрес или сеть';
    });

    if (isAlive) {
      await apiService.updateBaseUrl(url);
      if (mounted) {
        ToastHelper.show(
          context,
          message: 'Подключено к серверу!',
          icon: '🌐',
        );
      }
    }
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🛡️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Политика обработки ПДн',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Соответствие 152-ФЗ РФ «О персональных данных»:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• Все медицинские данные о членах семьи, графиках приёма препаратов и рецептах шифруются по стандарту ГОСТ / AES-256 GCM.\n'
                '• Пароли пользователей защищены алгоритмом хэширования Argon2id с солью.\n'
                '• Персональные данные хранятся на защищенных серверах на территории РФ в соответствии со ст. 18 152-ФЗ.\n'
                '• Приложение не передает персональные сведения третьим лицам без явного согласия владельца аккаунта.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    bool obscureCurrent = true;
    bool obscureNew = true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.password_rounded, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text(
                  'Смена пароля',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Хеширование Argon2id обеспечивает криптостойкую защиту мастер-пароля.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('change_password_current_input'),
                      controller: currentPassController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Текущий пароль',
                        labelStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                      validator: (val) => (val == null || val.isEmpty) ? 'Введите текущий пароль' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('change_password_new_input'),
                      controller: newPassController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Новый пароль',
                        labelStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Введите новый пароль';
                        if (val.length < 8) return 'Минимум 8 символов';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('change_password_confirm_input'),
                      controller: confirmPassController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Подтверждение нового пароля',
                        labelStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val != newPassController.text) return 'Пароли не совпадают';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Отмена', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                key: const Key('change_password_submit_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSubmitting = true);
                        final appState = context.read<AppState>();
                        final result = await appState.updatePassword(
                          currentPassword: currentPassController.text.trim(),
                          newPassword: newPassController.text.trim(),
                          newPasswordConfirmation: confirmPassController.text.trim(),
                        );
                        if (!context.mounted) return;
                        setDialogState(() => isSubmitting = false);
                        if (result['success'] == true) {
                          Navigator.pop(ctx);
                          ToastHelper.show(
                            context,
                            message: 'Пароль успешно обновлен!',
                            icon: '🔑',
                          );
                        } else {
                          ToastHelper.show(
                            context,
                            message: result['message'] ?? 'Ошибка обновления пароля',
                            isError: true,
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Обновить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportPersonalData(BuildContext context) async {
    final appState = context.read<AppState>();
    ToastHelper.show(context, message: 'Формирование выгрузки 152-ФЗ...', icon: '⏳');

    try {
      final data = await appState.exportPersonalData();
      if (!context.mounted) return;

      final prettyJson = const JsonEncoder.withIndent('  ').convert(data);
      final profilesCount = (data['profiles'] as List?)?.length ?? 0;
      final boxesCount = (data['medicine_boxes'] as List?)?.length ?? 0;

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.download_for_offline_outlined, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Выгрузка данных (152-ФЗ)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryBorderLight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('$profilesCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryHover)),
                          const Text('Профилей', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                      Container(height: 24, width: 1, color: AppColors.border),
                      Column(
                        children: [
                          Text('$boxesCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryHover)),
                          const Text('Аптечек', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                      Container(height: 24, width: 1, color: AppColors.border),
                      const Column(
                        children: [
                          Text('AES-256', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryHover)),
                          Text('Расшифровано', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'В соответствии со ст. 14 152-ФЗ вам предоставляется полный машиночитаемый дамп учетных данных:',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 150,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      prettyJson,
                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('Скопировать JSON'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: prettyJson));
                ToastHelper.show(context, message: 'JSON скопирован в буфер обмена', icon: '📋');
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ToastHelper.show(context, message: 'Ошибка формирования выгрузки: $e', isError: true);
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final passwordController = TextEditingController();
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                SizedBox(width: 8),
                Text(
                  'Удаление аккаунта',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Text(
                      'Право на забвение (ст. 21 152-ФЗ РФ):\n'
                      'Все связанные персональные данные (профили семьи, медицинские заметки, курсы приёма и личные аптечки) будут безвозвратно уничтожены, а токены доступа аннулированы.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF991B1B), height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Для подтверждения удаления введите текущий пароль:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('delete_account_password_input'),
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Текущий пароль',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Отмена', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                key: const Key('delete_account_confirm_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final pass = passwordController.text.trim();
                        if (pass.isEmpty) {
                          ToastHelper.show(context, message: 'Введите пароль', isError: true);
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        final appState = context.read<AppState>();
                        final result = await appState.destroyAccount(currentPassword: pass);
                        if (!context.mounted) return;
                        setDialogState(() => isSubmitting = false);
                        if (result['success'] == true) {
                          Navigator.pop(ctx);
                          ToastHelper.show(
                            context,
                            message: 'Аккаунт и персональные данные успешно удалены.',
                            icon: '🗑️',
                          );
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        } else {
                          ToastHelper.show(
                            context,
                            message: result['message'] ?? 'Неверный пароль',
                            isError: true,
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Удалить данные навсегда'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final apiService = context.watch<ApiService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Настройки',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // 1. Default Schedule Times
          _buildSectionHeader('ВРЕМЯ ПРИЁМОВ ПО УМОЛЧАНИЮ', Icons.access_time_rounded),
          _buildCardContainer([
            _buildTimeRow(
              title: 'Утро (приём 1)',
              subtitle: 'Перед завтраком или пробуждение',
              time: state.morningTime,
              onTap: () => _pickTime(state, 'morning', state.morningTime),
            ),
            const Divider(height: 1, indent: 16, color: AppColors.border),
            _buildTimeRow(
              title: 'Обед (приём 2)',
              subtitle: 'Дневной приём во время или после еды',
              time: state.lunchTime,
              onTap: () => _pickTime(state, 'lunch', state.lunchTime),
            ),
            const Divider(height: 1, indent: 16, color: AppColors.border),
            _buildTimeRow(
              title: 'Вечер (приём 3)',
              subtitle: 'Перед ужином или перед сном',
              time: state.eveningTime,
              onTap: () => _pickTime(state, 'evening', state.eveningTime),
            ),
            const Divider(height: 1, indent: 16, color: AppColors.border),
            _buildTimeRow(
              title: 'Ночь (приём 4)',
              subtitle: 'Непосредственно перед сном',
              time: state.nightTime,
              onTap: () => _pickTime(state, 'night', state.nightTime),
            ),
          ]),

          const SizedBox(height: 20),

          // 2. Notifications & Reminders
          _buildSectionHeader('УВЕДОМЛЕНИЯ И НАПОМИНАНИЯ', Icons.notifications_none_rounded),
          _buildCardContainer([
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              title: const Text(
                'Напоминания о приёме',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Push-уведомления и звуковые сигналы',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              activeTrackColor: AppColors.primaryLight,
              activeThumbColor: AppColors.primary,
              value: state.remindersEnabled,
              onChanged: (val) => state.setRemindersEnabled(val),
            ),
            const Divider(height: 1, indent: 16, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Напомнить за',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Упреждающий сигнал до приёма',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  DropdownButton<int>(
                    value: state.reminderOffsetMinutes,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryHover),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 мин', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 15, child: Text('15 мин', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 30, child: Text('30 мин', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    ],
                    onChanged: (val) {
                      if (val != null) state.setReminderOffsetMinutes(val);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, color: AppColors.border),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              title: const Text(
                'Повтор напоминания при пропуске',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Повторять через 10 минут, пока таблетка не принята',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              activeTrackColor: AppColors.primaryLight,
              activeThumbColor: AppColors.primary,
              value: state.repeatOnMissed,
              onChanged: (val) => state.setRepeatOnMissed(val),
            ),
          ]),

          const SizedBox(height: 20),

          // 3. Synchronization & Server
          _buildSectionHeader('СИНХРОНИЗАЦИЯ И СЕРВЕР', Icons.cloud_sync_outlined),
          _buildCardContainer([
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'АДРЕС СЕРВЕРА REST API',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _serverUrlController,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceSubtle,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Quick switch buttons
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
                        label: const Text('☁️ swtest.ru основной', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                        backgroundColor: AppColors.primarySurface,
                        side: const BorderSide(color: AppColors.primaryBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () {
                          _serverUrlController.text = 'http://e340043kek.temp.swtest.ru/api';
                          apiService.updateBaseUrl('http://e340043kek.temp.swtest.ru/api');
                        },
                      ),
                      ActionChip(
                        label: const Text('🌐 bluzaus.swtest.ru зеркало', style: TextStyle(fontSize: 10)),
                        backgroundColor: AppColors.surfaceSubtle,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () {
                          _serverUrlController.text = 'http://bluzaus.ru.swtest.ru/api';
                          apiService.updateBaseUrl('http://bluzaus.ru.swtest.ru/api');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Check connection button
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primaryHover,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isCheckingConnection
                          ? null
                          : () => _checkServerConnection(apiService),
                      icon: _isCheckingConnection
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.wifi_find_rounded, size: 16),
                      label: Text(
                        _isCheckingConnection ? 'Проверка...' : 'Проверить связь с сервером',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  if (_connectionStatus != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _connectionSuccess == true
                            ? AppColors.statusOkBg
                            : AppColors.statusExpiredBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _connectionSuccess == true
                              ? AppColors.statusOkDot.withValues(alpha: 0.3)
                              : AppColors.statusExpiredBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _connectionSuccess == true
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            size: 14,
                            color: _connectionSuccess == true
                                ? AppColors.statusOkText
                                : AppColors.statusExpiredText,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _connectionStatus!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _connectionSuccess == true
                                    ? AppColors.statusOkText
                                    : AppColors.statusExpiredText,
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
            const Divider(height: 1, indent: 16, color: AppColors.border),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              title: const Text(
                'Автономный демо-режим (без сети)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Локальные профили и лекарства без отправки на сервер',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              activeTrackColor: AppColors.primaryLight,
              activeThumbColor: AppColors.primary,
              value: apiService.isMockMode,
              onChanged: (val) {
                setState(() => apiService.isMockMode = val);
                ToastHelper.show(
                  context,
                  message: val ? 'Демо-режим активирован' : 'Режим сети активен',
                  icon: val ? '✈️' : '🌐',
                );
              },
            ),
          ]),

          const SizedBox(height: 20),

          // 4. Privacy & 152-FZ Security
          _buildSectionHeader('КОНФИДЕНЦИАЛЬНОСТЬ И БЕЗОПАСНОСТЬ (152-ФЗ)', Icons.security_rounded),
          _buildCardContainer([
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.statusOkBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.statusOkText),
              ),
              title: const Text(
                'Шифрование AES-256 / Argon2id',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Локальный стек защиты данных активен',
                style: TextStyle(fontSize: 11, color: AppColors.statusOkText, fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.check_circle_rounded, color: AppColors.statusOkDot, size: 18),
            ),
            const Divider(height: 1, indent: 16, color: AppColors.border),
            SwitchListTile(
              key: const Key('settings_biometric_switch'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              secondary: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _isBiometricEnabled ? AppColors.statusOkBg : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isBiometricEnabled ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Icon(
                  Icons.fingerprint_rounded,
                  size: 20,
                  color: _isBiometricEnabled ? AppColors.statusOkDot : const Color(0xFF64748B),
                ),
              ),
              title: const Text(
                'Биометрическая защита (Touch ID / Face ID)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Быстрая аутентификация при разблокировке приложения',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              activeTrackColor: AppColors.primaryLight,
              activeThumbColor: AppColors.primary,
              value: _isBiometricEnabled,
              onChanged: (val) async {
                final biometricService = _getBiometricService();
                if (val) {
                  final authenticated = await biometricService.authenticate(
                    localizedReason: 'Подтвердите биометрию для активации быстрого входа',
                  );
                  if (authenticated) {
                    setState(() => _isBiometricEnabled = true);
                    await biometricService.setBiometricAuthEnabled(true);
                    if (context.mounted) {
                      ToastHelper.show(
                        context,
                        message: 'Биометрическая защита включена',
                        icon: '🔒',
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ToastHelper.show(
                        context,
                        message: 'Не удалось подтвердить биометрию',
                        icon: '⚠️',
                      );
                    }
                  }
                } else {
                  setState(() => _isBiometricEnabled = false);
                  await biometricService.setBiometricAuthEnabled(false);
                  if (context.mounted) {
                    ToastHelper.show(
                      context,
                      message: 'Биометрическая защита отключена',
                      icon: '🔓',
                    );
                  }
                }
              },
            ),
            const Divider(height: 1, indent: 16, color: AppColors.border),
            ListTile(
              key: const Key('settings_privacy_consent_tile'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _isConsentAccepted ? AppColors.statusOkBg : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  size: 20,
                  color: _isConsentAccepted ? AppColors.statusOkText : const Color(0xFFD97706),
                ),
              ),
              title: const Text(
                'Согласие на обработку данных (152-ФЗ)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              subtitle: Text(
                _isConsentAccepted
                    ? 'Принято: редакция ${_consentVersion ?? "v1.0-2026"}${_consentDate != null ? " (${_consentDate!.split("T").first})" : ""}'
                    : 'Требуется подтверждение согласия',
                style: TextStyle(
                  fontSize: 11,
                  color: _isConsentAccepted ? AppColors.statusOkText : const Color(0xFFB45309),
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: _isConsentAccepted
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.statusOkDot, size: 18)
                  : const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
              onTap: () async {
                final accepted = await PrivacyConsentDialog.show(
                  context,
                  storageService: apiService.storageService,
                );
                if (accepted == true) {
                  await _loadConsentStatus();
                  if (context.mounted) {
                    ToastHelper.show(
                      context,
                      message: 'Согласие 152-ФЗ успешно зафиксировано',
                      icon: '🛡️',
                    );
                  }
                }
              },
            ),
            const Divider(height: 1, indent: 16, color: AppColors.border),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_outlined, size: 20, color: AppColors.primaryHover),
              ),
              title: const Text(
                'Политика обработки данных',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Регламент защиты персональных данных',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: () => _showPrivacyPolicyDialog(context),
            ),
            const Divider(height: 1, indent: 16, color: AppColors.border),
            ListTile(
              key: const Key('settings_onboarding_tile'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: const Icon(Icons.auto_stories_rounded, size: 20, color: Color(0xFF4F46E5)),
              ),
              title: const Text(
                'Гид по функциям (Онбординг)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Защита 152-ФЗ, FEFO-Opened контроль и CDS-движок',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
              onTap: () {
                OnboardingGuideDialog.show(
                  context,
                  storageService: apiService.storageService,
                );
              },
            ),
            const Divider(height: 1, indent: 16, color: AppColors.border),
            ListTile(
              key: const Key('settings_change_password_tile'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Icon(Icons.password_rounded, size: 20, color: Color(0xFF334155)),
              ),
              title: const Text(
                'Смена пароля (Argon2id)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Обновление мастер-пароля учетной записи',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: () => _showChangePasswordDialog(context),
            ),
            const Divider(height: 1, indent: 16, color: AppColors.border),
            ListTile(
              key: const Key('settings_export_data_tile'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryBorderLight),
                ),
                child: const Icon(Icons.download_for_offline_outlined, size: 20, color: AppColors.primaryHover),
              ),
              title: const Text(
                'Экспорт персональных данных (DSAR)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Выгрузка архива данных в формате JSON (ст. 14 152-ФЗ)',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: () => _exportPersonalData(context),
            ),
            const Divider(height: 1, indent: 16, color: AppColors.border),
            ListTile(
              key: const Key('settings_delete_account_tile'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Icon(Icons.delete_forever_rounded, size: 20, color: Color(0xFFDC2626)),
              ),
              title: const Text(
                'Удаление учетной записи (ст. 21 152-ФЗ)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
              ),
              subtitle: const Text(
                'Право на забвение: полное уничтожение персональных данных',
                style: TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFDC2626)),
              onTap: () => _showDeleteAccountDialog(context),
            ),
          ]),

          const SizedBox(height: 20),

          // Admin Security Panel (LR 2 Table 1 rows 4-5)
          if ((state.currentUser?.isAdmin == true) || apiService.isMockMode) ...[
            _buildSectionHeader('АДМИНИСТРИРОВАНИЕ БЕЗОПАСНОСТИ (РБАК / ЛР 2)', Icons.admin_panel_settings_outlined),
            _buildCardContainer([
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: const Text('🛡️', style: TextStyle(fontSize: 20)),
                ),
                title: const Text(
                  '🛡️ Панель администратора безопасности',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'Блокировка пользователей, аудит сессий и эталонный справочник ГРЛС',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                  );
                },
              ),
            ]),
            const SizedBox(height: 20),
          ],

          const SizedBox(height: 20),

          // 5. About Application
          _buildSectionHeader('О ПРИЛОЖЕНИИ', Icons.info_outline_rounded),
          _buildCardContainer([
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primaryBorderLight),
                        ),
                        alignment: Alignment.center,
                        child: const Text('💊', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Семейная Аптечка',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Версия 1.0.0-beta (Сборка 2026.1)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 10),
                  const Text(
                    'Разработка защищенной информационной системы управления персональными запасами лекарственных средств.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.school_outlined, size: 14, color: AppColors.primaryHover),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'МГУ им. Н.П. Огарёва · ФМиИТ · 09.04.04',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    ),
  );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.primaryHover),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildTimeRow({
    required String title,
    required String subtitle,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryBorderLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 13, color: AppColors.primaryHover),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeOfDay(time),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryHover,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
