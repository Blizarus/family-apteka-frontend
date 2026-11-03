import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../theme/app_theme.dart';

const bool kScannerDebug = bool.fromEnvironment('SCANNER_DEBUG', defaultValue: false);

class BarcodeScannerSheet extends StatefulWidget {
  const BarcodeScannerSheet({super.key});

  /// Opens camera scanner modal and returns detected barcode string (or null if cancelled).
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const BarcodeScannerSheet(),
    );
  }

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final MobileScannerController _controller;
  late final AnimationController _laserAnimationController;
  final TextEditingController _manualCodeController = TextEditingController();

  bool _isTorchOn = false;
  bool _hasDetected = false;
  bool _isRetrying = false;
  bool _isTimedOut = false;
  bool _showDebugHud = kScannerDebug;

  Timer? _timeoutTimer;
  Timer? _secondsTimer;
  int _secondsElapsed = 0;
  MobileScannerException? _lastError;
  String _deviceInfo = 'Определение устройства...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
    );

    _laserAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _secondsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });

    _startTimeoutWatcher();
    _fetchDeviceInfo();
  }

  Future<void> _fetchDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        if (mounted) {
          setState(() {
            _deviceInfo = '${info.manufacturer.toUpperCase()} ${info.model} (Android ${info.version.release}, API ${info.version.sdkInt})';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _deviceInfo = '${Platform.operatingSystem} (${Platform.operatingSystemVersion})';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _deviceInfo = 'Android ${Platform.operatingSystemVersion}';
        });
      }
    }
  }

  void _startTimeoutWatcher() {
    _timeoutTimer?.cancel();
    _isTimedOut = false;
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_controller.value.isRunning && !_hasDetected) {
        setState(() {
          _isTimedOut = true;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retryCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    _secondsTimer?.cancel();
    _laserAnimationController.dispose();
    _controller.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  Future<void> _retryCamera() async {
    if (_isRetrying || !mounted) return;
    setState(() {
      _isRetrying = true;
      _isTimedOut = false;
      _secondsElapsed = 0;
    });
    _startTimeoutWatcher();
    try {
      await _controller.stop();
    } catch (_) {}
    try {
      await _controller.start();
    } catch (e) {
      if (e is MobileScannerException) {
        _lastError = e;
      }
    }
    if (mounted) {
      setState(() => _isRetrying = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;

    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode != null && barcode.trim().isNotEmpty) {
      _hasDetected = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(barcode.trim());
    }
  }

  void _submitManualCode([String? code]) {
    final value = (code ?? _manualCodeController.text).trim();
    if (value.isNotEmpty) {
      _hasDetected = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(value);
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final capture = await _controller.analyzeImage(image.path);
      final barcode = capture?.barcodes.firstOrNull?.rawValue;
      if (barcode != null && barcode.trim().isNotEmpty) {
        _submitManualCode(barcode.trim());
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Штрихкод на выбранном фото не обнаружен. Попробуйте другое фото или введите код вручную.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка анализа изображения: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanWindowSize = size.width * 0.72;

    return Container(
      height: size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Camera Viewfinder with inline error handling
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                _lastError = error;
                return _buildCameraFallbackView(error: error);
              },
            ),
          ),

          // Fallback overlay when 8s timeout triggers without camera feed
          if (_isTimedOut && !_controller.value.isRunning)
            Positioned.fill(
              child: _buildCameraFallbackView(isTimeout: true),
            ),

          // 2. Targeting Overlay with Laser (visible only when camera is running)
          if (!_isTimedOut && _lastError == null)
            Positioned.fill(
              child: _buildScannerOverlay(scanWindowSize),
            ),

          // 3. Diagnostic HUD (when SCANNER_DEBUG=true or toggled)
          if (_showDebugHud)
            Positioned(
              top: 60,
              left: 12,
              right: 12,
              child: _buildDiagnosticHud(),
            ),

          // 4. Top Action Bar: Close, Title, Controls
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                  onPressed: () => Navigator.of(context).pop(),
                ),

                // Title
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF2DD4BF)),
                      SizedBox(width: 6),
                      Text(
                        'EAN-13 / DataMatrix',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Controls: Torch, Switch, Gallery, Debug toggle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 20),
                      style: IconButton.styleFrom(backgroundColor: Colors.black45),
                      tooltip: 'Выбрать фото из галереи',
                      onPressed: _pickImageFromGallery,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _isTorchOn ? const Color(0xFFFDE047) : Colors.white,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(backgroundColor: Colors.black45),
                      onPressed: _toggleTorch,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 20),
                      style: IconButton.styleFrom(backgroundColor: Colors.black45),
                      onPressed: _switchCamera,
                    ),
                    if (kDebugMode || kScannerDebug) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.bug_report_rounded,
                          color: _showDebugHud ? const Color(0xFF2DD4BF) : Colors.white38,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(backgroundColor: Colors.black45),
                        onPressed: () => setState(() => _showDebugHud = !_showDebugHud),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 5. Bottom Hint & Quick test buttons
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Text(
                    'Наведите камеру на штрихкод упаковки или DataMatrix-код «Честный Знак»',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Fallback Quick Barcode (EAN-13 Ибупрофен) for instant testing / web
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: const Color(0xFF2DD4BF),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF14B8A6), width: 0.8),
                    ),
                  ),
                  onPressed: () => _submitManualCode('4601234567890'),
                  icon: const Icon(Icons.flash_auto_rounded, size: 16),
                  label: const Text(
                    'Тестовый штрихкод: Ибупрофен (4601234567890)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticHud() {
    final state = _controller.value;
    final hasPerm = _lastError?.errorCode != MobileScannerErrorCode.permissionDenied;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2DD4BF), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.developer_mode_rounded, size: 16, color: Color(0xFF2DD4BF)),
              const SizedBox(width: 6),
              const Text(
                'SCANNER_DEBUG DIAGNOSTICS',
                style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              const Spacer(),
              Text(
                '${_secondsElapsed}s',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 12),
          _buildDiagRow('Device / OS:', _deviceInfo),
          _buildDiagRow('isInitialized:', '${state.isInitialized}'),
          _buildDiagRow('isRunning:', '${state.isRunning}'),
          _buildDiagRow('hasPermission:', hasPerm ? 'YES (Granted)' : 'NO (Denied/Pending)'),
          _buildDiagRow('Timeout 8s:', _isTimedOut ? 'TRIGGERED (Fallback active)' : 'OK (< 8s)'),
          _buildDiagRow(
            'Last Error:',
            _lastError != null
                ? '${_lastError!.errorCode.name} (${_lastError!.errorDetails?.message ?? "no message"})'
                : 'None',
            isWarning: _lastError != null,
          ),
        ],
      ),
    );
  }

  Widget _buildDiagRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isWarning ? const Color(0xFFFBBF24) : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(double windowSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final left = (constraints.maxWidth - windowSize) / 2;
        final top = (constraints.maxHeight - windowSize) / 2 - 20;

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: windowSize,
              height: windowSize,
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(windowSize, windowSize),
                    painter: _TargetFramePainter(color: AppColors.primaryLight),
                  ),
                  AnimatedBuilder(
                    animation: _laserAnimationController,
                    builder: (context, child) {
                      final lineY = windowSize * _laserAnimationController.value;
                      return Positioned(
                        top: lineY,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryLight.withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCameraFallbackView({MobileScannerException? error, bool isTimeout = false}) {
    final bool isPermission = error?.errorCode == MobileScannerErrorCode.permissionDenied;

    String title;
    String reason;
    IconData icon;
    Color iconColor;

    if (isPermission) {
      title = 'Требуется доступ к камере';
      reason = 'Предоставьте разрешение на использование камеры в системных настройках телефона для сканирования штрихкодов.';
      icon = Icons.videocam_off_rounded;
      iconColor = const Color(0xFFFBBF24);
    } else if (isTimeout) {
      title = 'Камера не ответила за 8 секунд';
      reason = 'Инициализация сенсора камеры превысила тайм-аут (камера занята другим приложением или сенсор медленно запускается). Выберите другой способ:';
      icon = Icons.timer_off_rounded;
      iconColor = const Color(0xFFF97316);
    } else if (error != null) {
      title = 'Ошибка запуска камеры';
      reason = 'Код ошибки: ${error.errorCode.name}. ${error.errorDetails?.message ?? "Повторите попытку или выберите изображение из галереи."}';
      icon = Icons.error_outline_rounded;
      iconColor = const Color(0xFFEF4444);
    } else {
      title = 'Камера подключается...';
      reason = 'Ожидание ответа аппаратного сенсора камеры. Вы можете ввести штрихкод вручную или загрузить фото:';
      icon = Icons.camera_alt_outlined;
      iconColor = const Color(0xFF2DD4BF);
    }

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: iconColor),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 1. Retry / Request Permission
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isRetrying ? null : _retryCamera,
                  icon: _isRetrying
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(isPermission ? Icons.lock_open_rounded : Icons.refresh_rounded, size: 16),
                  label: Text(_isRetrying ? 'Подключение...' : (isPermission ? 'Разрешить доступ' : 'Повторить попытку')),
                ),

                // 2. Pick photo from gallery
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF2DD4BF), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _pickImageFromGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 16, color: Color(0xFF2DD4BF)),
                  label: const Text('Выбрать фото'),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),
            const Text(
              'ИЛИ ВВЕДИТЕ ШТРИХКОД ВРУЧНУЮ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 14),

            // Manual code entry
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCodeController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '4601234567890',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2DD4BF)),
                      ),
                    ),
                    onSubmitted: _submitManualCode,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _submitManualCode(),
                  child: const Text('Применить', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick preset buttons
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  backgroundColor: Colors.white12,
                  label: const Text('Ибупрофен (4601234567890)', style: TextStyle(color: Colors.white, fontSize: 11)),
                  onPressed: () => _submitManualCode('4601234567890'),
                ),
                ActionChip(
                  backgroundColor: Colors.white12,
                  label: const Text('Амоксициллин (4607008123456)', style: TextStyle(color: Colors.white, fontSize: 11)),
                  onPressed: () => _submitManualCode('4607008123456'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetFramePainter extends CustomPainter {
  final Color color;

  _TargetFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;

    // Top-left corner
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top-right corner
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-left corner
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom-right corner
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
