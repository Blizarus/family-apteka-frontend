import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../screens/login_screen.dart';

/// Виджет-гейткипер биометрической аутентификации (DEF-18).
/// Защищает доступ к главному экрану при активном токене авторизации,
/// если в настройках включена защита биометрией / PIN-кодом устройства.
class AppLockGate extends StatefulWidget {
  final Widget child;
  final BiometricService? biometricService;

  const AppLockGate({
    super.key,
    required this.child,
    this.biometricService,
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _isChecking = true;
  bool _isUnlocked = false;
  DateTime? _pausedAt;
  static const Duration _lockTimeout = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        _pausedAt = null;
        if (elapsed >= _lockTimeout) {
          final apiService = context.read<ApiService>();
          apiService.storageService.isBiometricEnabled().then((enabled) {
            if (enabled && mounted) {
              setState(() {
                _isUnlocked = false;
              });
              _authenticate();
            }
          });
        }
      }
    }
  }

  Future<void> _checkBiometricLock() async {
    final apiService = context.read<ApiService>();
    final isEnabled = await apiService.storageService.isBiometricEnabled();

    if (!isEnabled) {
      if (mounted) {
        setState(() {
          _isUnlocked = true;
          _isChecking = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isUnlocked = false;
        _isChecking = false;
      });
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    final apiService = context.read<ApiService>();
    final bioService = widget.biometricService ?? apiService.biometricService;

    final success = await bioService.authenticate(
      localizedReason: 'Подтвердите личность для входа в Семейную аптечку',
      biometricOnly: false,
    );

    if (mounted) {
      setState(() {
        _isUnlocked = success;
      });
    }
  }

  Future<void> _logout() async {
    final apiService = context.read<ApiService>();
    await apiService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (_isUnlocked) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 48,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Вход заблокирован',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Для доступа к медицинским данным подтвердите личность с помощью биометрии или PIN-кода.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                FilledButton.icon(
                  key: const Key('app_lock_unlock_button'),
                  onPressed: _authenticate,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Разблокировать'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  key: const Key('app_lock_logout_button'),
                  onPressed: _logout,
                  child: Text(
                    'Выйти из аккаунта',
                    style: TextStyle(color: cs.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
