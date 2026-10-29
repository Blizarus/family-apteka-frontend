import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/api_error_handler.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/toast_helper.dart';
import '../widgets/server_config_dialog.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegisterMode = false;

  final TextEditingController _nameController =
      TextEditingController(text: 'Иван Марков');
  final TextEditingController _emailController =
      TextEditingController(text: 'anna@family.test');
  final TextEditingController _passwordController =
      TextEditingController(text: 'password');
  final TextEditingController _passwordConfirmController =
      TextEditingController(text: 'password');

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // 152-ФЗ and Cloud Sync toggles
  bool _termsAccepted = false;
  bool _syncEnabled = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ToastHelper.show(
        context,
        message: 'Пожалуйста, заполните email и пароль',
        isError: true,
        icon: '⚠️',
      );
      return;
    }

    setState(() => _isLoading = true);

    final apiService = context.read<ApiService>();

    try {
      await apiService.login(email, password);

      if (!mounted) return;

      // Reload app state with fresh data from backend
      await context.read<AppState>().loadInitialData();

      if (!mounted) return;

      ToastHelper.show(
        context,
        message: 'Добро пожаловать в Семейную Аптечку!',
        icon: '✓',
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      final cleanMsg = ApiErrorHandler.format(e, defaultMessage: 'Не удалось войти в аккаунт');
      ToastHelper.show(
        context,
        message: cleanMsg,
        isError: true,
        icon: '✕',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final passwordConfirm = _passwordConfirmController.text.trim();

    if (name.isEmpty) {
      ToastHelper.show(
        context,
        message: 'Пожалуйста, укажите ваше имя',
        isError: true,
        icon: '⚠️',
      );
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      ToastHelper.show(
        context,
        message: 'Пожалуйста, укажите корректный email',
        isError: true,
        icon: '⚠️',
      );
      return;
    }

    if (password.length < 8) {
      ToastHelper.show(
        context,
        message: 'Пароль должен содержать не менее 8 символов',
        isError: true,
        icon: '⚠️',
      );
      return;
    }

    if (password != passwordConfirm) {
      ToastHelper.show(
        context,
        message: 'Введенные пароли не совпадают',
        isError: true,
        icon: '⚠️',
      );
      return;
    }

    if (!_termsAccepted) {
      ToastHelper.show(
        context,
        message: 'Необходимо подтвердить согласие на обработку персональных данных (152-ФЗ)',
        isError: true,
        icon: '🔒',
      );
      return;
    }

    setState(() => _isLoading = true);

    final apiService = context.read<ApiService>();

    try {
      await apiService.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirm,
        termsAccepted: _termsAccepted,
        syncEnabled: _syncEnabled,
      );

      if (!mounted) return;

      // Reload initial data
      await context.read<AppState>().loadInitialData();

      if (!mounted) return;

      ToastHelper.show(
        context,
        message: 'Регистрация успешна! Добро пожаловать, $name!',
        icon: '🎉',
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      final cleanMsg = ApiErrorHandler.format(e, defaultMessage: 'Не удалось завершить регистрацию');
      ToastHelper.show(
        context,
        message: cleanMsg,
        isError: true,
        icon: '✕',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _fillTestCredentials() {
    setState(() {
      _emailController.text = 'anna@family.test';
      _passwordController.text = 'password';
      if (_isRegisterMode) {
        _nameController.text = 'Иван Марков';
        _passwordConfirmController.text = 'password';
        _termsAccepted = true;
      }
    });
    ToastHelper.show(
      context,
      message: 'Тестовые данные подставлены',
      icon: '🔑',
    );
  }

  void _show152FZInfoModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🔒', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Защита данных (152-ФЗ)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'В соответствии с Федеральным законом РФ № 152-ФЗ «О персональных данных»:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              SizedBox(height: 8),
              Text(
                '• Все медицинские записи, рецепты и сведения о состоянии здоровья шифруются современным алгоритмом AES-256.\n'
                '• Аутентификация защищена криптографическим хэшированием паролей Argon2id.\n'
                '• При отключенной синхронизации ваши данные хранятся исключительно на вашем личном устройстве и не передаются во внешнюю сеть.\n'
                '• Серверная база данных размещается строго в защищенном контуре в соответствии с требованиями законодательства РФ.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45),
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 520;

        Widget content = Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo & Icon (Long Press to configure server API URL)
                    GestureDetector(
                      onLongPress: () => ServerConfigDialog.show(context),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.primaryBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Text('💊', style: TextStyle(fontSize: 34)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title & Subtitle
                          const Text(
                            'Семейная Аптечка',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isRegisterMode
                          ? 'Health-Tech Minimal • Регистрация по 152-ФЗ'
                          : 'Health-Tech Minimal • Вход в систему',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Auth Mode Selector: [ Вход | Регистрация ]
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                if (_isRegisterMode) {
                                  setState(() => _isRegisterMode = false);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isRegisterMode ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: !_isRegisterMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Вход',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !_isRegisterMode
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: !_isRegisterMode
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                if (!_isRegisterMode) {
                                  setState(() => _isRegisterMode = true);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isRegisterMode ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _isRegisterMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Регистрация',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _isRegisterMode
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: _isRegisterMode
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Card Form
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // In Registration mode: Full Name field
                          if (_isRegisterMode) ...[
                            const Text(
                              'ВАШЕ ИМЯ ИЛИ ПСЕВДОНИМ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: TextField(
                                controller: _nameController,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                    color: AppColors.primaryHover,
                                    size: 18,
                                  ),
                                  hintText: 'Иван Марков',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Email Field
                          const Text(
                            'ЭЛЕКТРОННАЯ ПОЧТА',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                prefixIcon: Icon(
                                  Icons.mail_outline_rounded,
                                  color: AppColors.primaryHover,
                                  size: 18,
                                ),
                                hintText: 'example@family.test',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          Text(
                            _isRegisterMode
                                ? 'ПАРОЛЬ (ОТ 8 СИМВОЛОВ)'
                                : 'ПАРОЛЬ',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppColors.primaryHover,
                                  size: 18,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                hintText: '••••••••',
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 13,
                                ),
                              ),
                            ),
                          ),

                          // In Registration mode: Confirm Password field
                          if (_isRegisterMode) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'ПОДТВЕРЖДЕНИЕ ПАРОЛЯ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: TextField(
                                controller: _passwordConfirmController,
                                obscureText: _obscureConfirmPassword,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  prefixIcon: const Icon(
                                    Icons.lock_reset_rounded,
                                    color: AppColors.primaryHover,
                                    size: 18,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: AppColors.textMuted,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                  hintText: '••••••••',
                                  hintStyle: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Mandatory 152-ФЗ Consent Checkbox
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _termsAccepted
                                    ? AppColors.primarySurface
                                    : const Color(0xFFFFF1F2), // subtle red warning if unchecked
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _termsAccepted
                                      ? AppColors.primaryBorder
                                      : const Color(0xFFFECDD3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _termsAccepted,
                                      activeColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      onChanged: (val) {
                                        setState(() => _termsAccepted = val ?? false);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            setState(() => _termsAccepted = !_termsAccepted);
                                          },
                                          child: Text(
                                            'Я согласен с политикой обработки персональных данных (152-ФЗ РФ)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _termsAccepted
                                                  ? AppColors.primaryDeep
                                                  : const Color(0xFF9F1239),
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () => _show152FZInfoModal(context),
                                          child: const Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text('🔒', style: TextStyle(fontSize: 10)),
                                              SizedBox(width: 4),
                                              Text(
                                                'Подробнее о криптозащите и 152-ФЗ',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Optional Cloud Sync Switch
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Text('🔄', style: TextStyle(fontSize: 12)),
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Облачная синхронизация',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _syncEnabled
                                              ? 'Синхронизация между семейными устройствами включена'
                                              : 'Если выключено — данные сохраняются только на этом устройстве',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _syncEnabled,
                                    activeThumbColor: AppColors.primary,
                                    activeTrackColor: AppColors.primaryBorderLight,
                                    onChanged: (val) {
                                      setState(() => _syncEnabled = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Submit Button (Login or Register)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (_isRegisterMode && !_termsAccepted)
                                    ? const Color(0xFFCBD5E1)
                                    : AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : (_isRegisterMode
                                      ? (_termsAccepted ? _handleRegister : () {
                                          ToastHelper.show(
                                            context,
                                            message: 'Необходимо согласие на обработку данных (152-ФЗ)',
                                            isError: true,
                                            icon: '🔒',
                                          );
                                        })
                                      : _handleLogin),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isRegisterMode
                                          ? 'Создать защищенный аккаунт'
                                          : 'Войти в аккаунт',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Quick Test Credentials Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDeep,
                        side: const BorderSide(color: AppColors.primaryBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isLoading ? null : _fillTestCredentials,
                      icon: const Text('⚡', style: TextStyle(fontSize: 15)),
                      label: Text(
                        _isRegisterMode
                            ? 'Заполнить демо-данными'
                            : 'Тестовый вход (anna@family.test)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!_isRegisterMode) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF4F46E5),
                          side: const BorderSide(color: Color(0xFFC7D2FE)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isLoading ? null : () {
                          setState(() {
                            _emailController.text = 'admin@family.test';
                            _passwordController.text = 'admin123';
                          });
                          ToastHelper.show(
                            context,
                            message: 'Данные администратора подставлены',
                            icon: '🛡️',
                          );
                        },
                        icon: const Text('🛡️', style: TextStyle(fontSize: 14)),
                        label: const Text(
                          'Вход администратора (admin@family.test)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),

                    // Preset Hint Info
                    const Text(
                      'Тестовые данные: anna@family.test (пароль: password) • admin@family.test (пароль: admin123)\nRate limit: 5 попыток в минуту • 152-ФЗ Protected',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Server Configuration Chip / Button
                    Center(
                      child: InkWell(
                        onTap: () => ServerConfigDialog.show(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                context.watch<ApiService>().isMockMode
                                    ? Icons.cloud_off_rounded
                                    : Icons.dns_rounded,
                                size: 14,
                                color: context.watch<ApiService>().isMockMode
                                    ? Colors.amber.shade700
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.watch<ApiService>().isMockMode
                                    ? 'Автономный режим (Демо)'
                                    : 'Сервер: swtest.ru',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.settings_outlined,
                                size: 13,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        if (!isDesktop) {
          return content;
        }

        // Desktop Preview Frame
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A), // Slate 900
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _isRegisterMode
                                ? 'Семейная Аптечка (Регистрация 152-ФЗ)'
                                : 'Семейная Аптечка (Вход)',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Health-Tech Minimal',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    width: double.infinity,
                    height: 840,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(44),
                      border: Border.all(color: const Color(0xFF334155), width: 8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: content,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
