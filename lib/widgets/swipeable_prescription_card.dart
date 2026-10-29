import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Кастомный виджет свайпа карточки назначения без использования Dismissible.
/// Реализован на базе GestureDetector с onHorizontalDragUpdate для гармоничной
/// конкуренции жестов в GestureArena со скроллом ListView на Android и iOS.
class SwipeablePrescriptionCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const SwipeablePrescriptionCard({
    super.key,
    required this.child,
    required this.onArchive,
    required this.onDelete,
    this.onTap,
  });

  @override
  State<SwipeablePrescriptionCard> createState() =>
      _SwipeablePrescriptionCardState();
}

class _SwipeablePrescriptionCardState extends State<SwipeablePrescriptionCard>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _hasTriggeredHaptic = false;
  late AnimationController _springController;
  Animation<double>? _springAnimation;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  /// Адаптивный порог свайпа: 28% ширины экрана (вместо фиксированных пикселей)
  double get threshold => MediaQuery.of(context).size.width * 0.28;

  void _onHorizontalDragStart(DragStartDetails details) {
    _springController.stop();
    _hasTriggeredHaptic = false;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.primaryDelta ?? 0.0;

      // Тактильный отклик strictly в момент первого пересечения адаптивного порога
      final crossed = _dragOffset.abs() >= threshold;
      if (crossed && !_hasTriggeredHaptic) {
        _hasTriggeredHaptic = true;
        HapticFeedback.mediumImpact();
      } else if (!crossed && _hasTriggeredHaptic) {
        _hasTriggeredHaptic = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final swipedRight = _dragOffset >= threshold;
    final swipedLeft = _dragOffset <= -threshold;

    if (swipedRight) {
      // Свайп вправо: фиксация действия архивации и моментальный показ Undo SnackBar
      widget.onArchive();
      setState(() {
        _dragOffset = 0.0;
        _hasTriggeredHaptic = false;
      });
    } else if (swipedLeft) {
      // Свайп влево: пружинный отскок назад и вызов диалога подтверждения удаления
      _springBack(onComplete: widget.onDelete);
    } else {
      // Не достигнут порог: плавный пружинный возврат (Curves.elasticOut)
      _springBack();
    }
  }

  void _springBack({VoidCallback? onComplete}) {
    _springAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.elasticOut),
    )..addListener(() {
        setState(() {
          _dragOffset = _springAnimation!.value;
        });
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          onComplete?.call();
          _hasTriggeredHaptic = false;
        }
      });

    _springController.forward(from: 0.0);
  }


  @override
  Widget build(BuildContext context) {
    final isSwipingRight = _dragOffset > 0;

    // Плавный расчет прогресса для прозрачности фонового действия
    final progress = (_dragOffset.abs() / threshold).clamp(0.0, 1.0);

    // Смягченная ротация листа: deltaX * 0.02 (максимум ±5 градусов)
    final deg = (_dragOffset * 0.02).clamp(-5.0, 5.0);
    final rotationRad = deg * (math.pi / 180.0);

    // Оборачиваем в RepaintBoundary для изолированного слоя перерисовки и идеальных 60/120 FPS
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Фоновый слой действия (Action Background)
          if (_dragOffset != 0.0)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isSwipingRight
                      ? const Color(0xFFCCFBF1) // Бирюзовый #CCFBF1 при свайпе вправо
                      : const Color(0xFFFFE4E6), // Розовый #FFE4E6 при свайпе влево
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment:
                    isSwipingRight ? Alignment.centerLeft : Alignment.centerRight,
                child: Opacity(
                  opacity: progress,
                  child: isSwipingRight
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '✓',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'В архив',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🗑️', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 8),
                            Text(
                              'Удалить',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFBE123C),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

          // 2. Передний план: трансформируемая карточка с мягкой ротацией
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: Transform.rotate(
              angle: rotationRad,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _onHorizontalDragStart,
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                onTap: widget.onTap,
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
