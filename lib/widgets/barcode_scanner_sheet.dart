import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

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
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _laserAnimationController;
  final TextEditingController _manualCodeController = TextEditingController();

  bool _isTorchOn = false;
  bool _hasDetected = false;
  bool _isCameraError = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
    );

    _laserAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserAnimationController.dispose();
    _controller.dispose();
    _manualCodeController.dispose();
    super.dispose();
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
      height: size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Camera Viewfinder
          if (!_isCameraError)
            Positioned.fill(
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error, child) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_isCameraError) {
                      setState(() => _isCameraError = true);
                    }
                  });
                  return _buildFallbackView();
                },
              ),
            )
          else
            Positioned.fill(child: _buildFallbackView()),

          // 2. Targeting Overlay with Laser
          if (!_isCameraError)
            Positioned.fill(
              child: _buildScannerOverlay(scanWindowSize),
            ),

          // 3. Top Action Bar: Close, Title, Torch, Flip
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

                // Controls: Flashlight & Camera Switch
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _isTorchOn ? const Color(0xFFFDE047) : Colors.white,
                        size: 22,
                      ),
                      style: IconButton.styleFrom(backgroundColor: Colors.black45),
                      onPressed: _toggleTorch,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 22),
                      style: IconButton.styleFrom(backgroundColor: Colors.black45),
                      onPressed: _switchCamera,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. Bottom Hint & Quick test buttons
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                const SizedBox(height: 10),

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

  Widget _buildScannerOverlay(double windowSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final left = (constraints.maxWidth - windowSize) / 2;
        final top = (constraints.maxHeight - windowSize) / 2 - 20;

        return Stack(
          children: [
            // Darkened border areas around scan window
            Positioned(
              left: left,
              top: top,
              width: windowSize,
              height: windowSize,
              child: Stack(
                children: [
                  // Corner target accents
                  CustomPaint(
                    size: Size(windowSize, windowSize),
                    painter: _TargetFramePainter(color: AppColors.primaryLight),
                  ),

                  // Animated glowing laser sweep line
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

  Widget _buildFallbackView() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              size: 48,
              color: Color(0xFF2DD4BF),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Камера недоступна (Web / Эмулятор)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Вы можете ввести считанный код вручную или нажать тестовый штрихкод',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 20),

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
