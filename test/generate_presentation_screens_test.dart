import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/widgets/cds_badge.dart';
import 'package:frontend/utils/medication_safety_helper.dart';

Future<void> loadAppFonts() async {
  try {
    final regular = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
    final loaderRegular = FontLoader('Roboto');
    loaderRegular.addFont(Future.value(ByteData.view(regular.buffer)));
    await loaderRegular.load();

    final bold = File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync();
    final loaderBold = FontLoader('Roboto');
    loaderBold.addFont(Future.value(ByteData.view(bold.buffer)));
    await loaderBold.load();

    final icons = File('assets/fonts/MaterialIcons-Regular.otf').readAsBytesSync();
    final loaderIcons = FontLoader('MaterialIcons');
    loaderIcons.addFont(Future.value(ByteData.view(icons.buffer)));
    await loaderIcons.load();
  } catch (e) {
    // ignore
  }
}

void copyToDestination(String goldenName, String destName) {
  final src = File('test/goldens/$goldenName');
  final destDir = Directory('../../Документация/03_Публикации_и_Конференции/Огаревские_чтения/images');
  if (!destDir.existsSync()) {
    destDir.createSync(recursive: true);
  }
  final dest = File('${destDir.path}/$destName');
  if (src.existsSync()) {
    src.copySync(dest.path);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
  });

  group('Generate 4 Presentation & Publication Screenshots', () {
    const screenWidth = 412.0;
    const screenHeight = 870.0;

    testWidgets('Screen 1 Today - Schedule, Taken, CDS badge, SnackBar', (tester) async {
      tester.view.physicalSize = const Size(screenWidth, screenHeight);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final cs = theme.colorScheme;
              final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;

                return Scaffold(
                  backgroundColor: theme.scaffoldBackgroundColor,
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: () {},
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'Назначить курс',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  body: SafeArea(
                    child: Stack(
                      children: [
                        ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          children: [
                            // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'СРЕДА, 4 НОЯБРЯ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: cs.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Расписание приёма',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded, size: 14, color: cs.onPrimaryContainer),
                                      const SizedBox(width: 4),
                                      Text(
                                        '1 / 3 принято',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: cs.onPrimaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.notifications_outlined, color: cs.onSurface),
                                      onPressed: () {},
                                    ),
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Text(
                                          '2',
                                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Calendar Strip
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today_rounded, size: 12, color: cs.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Сегодня',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'НОЯБРЬ 2026',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: cs.primary,
                                    ),
                                  ),
                                  Icon(Icons.calendar_month_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.6)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildCalendarDay(context, 'ПН', '2', false),
                                  _buildCalendarDay(context, 'ВТ', '3', false),
                                  _buildCalendarDay(context, 'СР', '4', true),
                                  _buildCalendarDay(context, 'ЧТ', '5', false),
                                  _buildCalendarDay(context, 'ПТ', '6', false),
                                  _buildCalendarDay(context, 'СБ', '7', false),
                                  _buildCalendarDay(context, 'ВС', '8', false),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Intake 1: Taken (Омепразол)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: semantic.successBg,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(Icons.check_rounded, color: semantic.success, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Омепразол 20 мг',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurface.withValues(alpha: 0.5),
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          '08:30 • До еды',
                                          style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: cs.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Осталось: 9 шт.',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: semantic.successBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '✓ Принято',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: semantic.successText),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.undo_rounded, size: 18, color: cs.primary),
                            ],
                          ),
                        ),

                        // Intake 2: Active / Upcoming (Амоксициллин 500 мг)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cs.primary, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'СЕЙЧАС (13:00)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: cs.onPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Анна (Мама)',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // CDS Safety Badge (Warning)
                              CdsBadge(
                                alert: CdsAlert(
                                  level: CdsAlertLevel.warning,
                                  title: 'Клиническая СППР (CDS): Предупреждение',
                                  message: 'Рекомендуется раздельный приём с антацидами.',
                                  recommendation: 'Выдержать интервал не менее 2 часов между приёмами.',
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                'Амоксициллин 500 мг',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Во время еды • 1 таб.',
                                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7)),
                              ),
                              const SizedBox(height: 8),

                              // Course info & Deduct qty
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.sync_rounded, size: 14, color: cs.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Курс: Антибиотик (день 4 из 7)',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'К списанию: 1 таб.',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurface),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Buttons
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: ElevatedButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(Icons.check_rounded, size: 16),
                                      label: const Text('Принято', style: TextStyle(fontWeight: FontWeight.w700)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: cs.primary,
                                        foregroundColor: cs.onPrimary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: OutlinedButton(
                                      onPressed: () {},
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: const Text('+15м', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: OutlinedButton(
                                      onPressed: () {},
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: const Text('Пропустить', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Intake 3: Evening
                        Container(
                          margin: const EdgeInsets.only(bottom: 80),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '20:00',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface),
                                  ),
                                  Text(
                                    'Вечер',
                                    style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.6)),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Витаминный комплекс',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'После ужина • 1 драже',
                                      style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6)),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Принять'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),

                    // Floating SnackBar notification (DEF-17 & Task Spec 1)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 76,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Приём зафиксирован (Остаток: 9 шт.)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Отменить',
                                style: TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/screen1_today.png'),
      );

      copyToDestination('screen1_today.png', 'screen1_today.png');
    });

    testWidgets('Screen 2 Out of Stock Modal - Preserving Q >= 0 Invariant', (tester) async {
      tester.view.physicalSize = const Size(screenWidth, screenHeight);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            body: Stack(
              children: [
                // Blurred / Darkened backdrop representing Today screen
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),

                // Center Dialog
                Center(
                  child: Container(
                    width: 360,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dialog Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFD97706),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Дефицит запаса в аптечке',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Dialog Main Text
                        const Text(
                          'Недостаточно препарата в аптечке для списания остатка (остаток: 0 шт.). Подтвердить приём без списания?',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Color(0xFF334155),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Medication Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.medication_rounded, size: 18, color: Color(0xFF0D9488)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Ибупрофен 400 мг',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Остаток: 0 шт.',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Invariant note
                        Row(
                          children: const [
                            Icon(Icons.shield_outlined, size: 14, color: Color(0xFF0D9488)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Инвариант Q ≥ 0: списание без подтверждения заблокировано',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0D9488),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {},
                              child: const Text(
                                'Отмена',
                                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onPressed: () {},
                              child: const Text('Подтвердить приём', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/screen2_out_of_stock.png'),
      );

      copyToDestination('screen2_out_of_stock.png', 'screen2_out_of_stock.png');
    });

    testWidgets('Screen 3 Inventory - Medicine Card, FEFO-Opened, Shelf Life', (tester) async {
      tester.view.physicalSize = const Size(screenWidth, screenHeight);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final cs = theme.colorScheme;
              final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;

              return Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                floatingActionButton: FloatingActionButton.extended(
                  onPressed: () {},
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Добавить препарат',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                body: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ИНВЕНТАРЬ АПТЕЧКИ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Домашняя аптечка',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                              ),
                              Text(
                                'Шкаф в коридоре (полка 2)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.medical_services_outlined, color: cs.primary, size: 20),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Search Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Поиск по названию или веществу...',
                                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                              ),
                            ),
                            Icon(Icons.qr_code_scanner_rounded, size: 18, color: cs.primary),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Filter chips
                      Row(
                        children: [
                          _buildFilterTab(context, 'Все', '6 шт.', true, cs.primary),
                          const SizedBox(width: 8),
                          _buildFilterTab(context, 'Истекают', '1 шт.', false, const Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          _buildFilterTab(context, 'Просрочены', '1 шт.', false, const Color(0xFFDC2626)),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Card 1: Ибупрофен 400 мг (With "Вскрыть упаковку" button)
                      _buildInventoryCard(
                        context,
                        name: 'Ибупрофен 400 мг',
                        substance: 'Ибупрофен',
                        form: 'Таблетки',
                        remaining: '16 / 20 шт.',
                        expiry: 'Срок: 11.2027',
                        badgeText: 'В норме',
                        badgeColor: semantic.success,
                        badgeBg: semantic.successBg,
                        badgeTextColor: semantic.successText,
                        actionWidget: OutlinedButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.lock_open_rounded, size: 14, color: cs.primary),
                          label: Text(
                            'Вскрыть упаковку',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),

                      // Card 2: Спрей Називин 0.05% (Opened: FEFO-Opened dynamic model)
                      _buildInventoryCard(
                        context,
                        name: 'Спрей Називин 0.05%',
                        substance: 'Оксиметазолин',
                        form: 'Спрей назальный',
                        remaining: '1 / 1 шт.',
                        expiry: 'Вскрыто: 12 дней назад • Годен до 20.11 (осталось 16 дн.)',
                        badgeText: 'Скоро истечет',
                        badgeColor: semantic.warning,
                        badgeBg: semantic.warningBg,
                        badgeTextColor: semantic.warningText,
                        highlightBorder: true,
                        specialNote: Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: semantic.warningBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: semantic.warningBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_rounded, size: 12, color: semantic.warningText),
                              const SizedBox(width: 4),
                              Text(
                                'ДИНАМИЧЕСКИЙ СРОК (FEFO-Opened): 28 дн. после вскрытия',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: semantic.warningText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Card 3: Амоксициллин 500 мг (Rx)
                      _buildInventoryCard(
                        context,
                        name: 'Амоксициллин 500 мг',
                        isRx: true,
                        substance: 'Амоксициллин',
                        form: 'Капсулы',
                        remaining: '8 / 16 шт.',
                        expiry: 'Срок: 02.2027',
                        badgeText: 'В норме',
                        badgeColor: semantic.success,
                        badgeBg: semantic.successBg,
                        badgeTextColor: semantic.successText,
                      ),

                      // Card 4: Аспирин Кардио 100 мг (Expired)
                      _buildInventoryCard(
                        context,
                        name: 'Аспирин Кардио 100 мг',
                        substance: 'Ацетилсалициловая кислота',
                        form: 'Таблетки кишечнорастворимые',
                        remaining: '4 / 20 шт.',
                        expiry: 'Срок истёк 09.2026',
                        badgeText: 'Просрочено!',
                        badgeColor: semantic.danger,
                        badgeBg: semantic.dangerBg,
                        badgeTextColor: semantic.dangerText,
                      ),

                      const SizedBox(height: 70),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/screen3_inventory.png'),
      );

      copyToDestination('screen3_inventory.png', 'screen3_inventory.png');
    });

    testWidgets('Screen 4 Security & Biometrics - Gatekeeper 152-FZ & Biometric Guard', (tester) async {
      tester.view.physicalSize = const Size(screenWidth, screenHeight);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final cs = theme.colorScheme;

              return Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                body: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Compliance Badge Top
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user_rounded, size: 14, color: cs.primary),
                                const SizedBox(width: 6),
                                Text(
                                  '152-ФЗ РФ • ГОСТ Р 56939-2024',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Biometric Icon Container
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.15),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.fingerprint_rounded,
                              size: 54,
                              color: cs.primary,
                            ),
                          ),

                          const SizedBox(height: 22),

                          Text(
                            'Подтвердите личность',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 10),

                          Text(
                            'Для доступа к персональной медицинской карте, аллергиям и графику приёма подтвердите личность с помощью биометрии (Touch ID / Face ID) или PIN-кода.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 24),

                          // Security Standards Box
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Column(
                              children: [
                                _buildSecurityRow(
                                  icon: Icons.lock_outline_rounded,
                                  title: 'Шифрование данных (E2EE):',
                                  value: 'AES-256 GCM (диагнозы, аллергии)',
                                  cs: cs,
                                ),
                                const Divider(height: 14),
                                _buildSecurityRow(
                                  icon: Icons.key_rounded,
                                  title: 'Хэширование аутентификации:',
                                  value: 'Argon2id (RFC 9106, OWASP ASVS)',
                                  cs: cs,
                                ),
                                const Divider(height: 14),
                                _buildSecurityRow(
                                  icon: Icons.dns_outlined,
                                  title: 'Локализация баз данных:',
                                  value: 'Серверы в РФ (ст. 18 152-ФЗ)',
                                  cs: cs,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Unlock button
                          FilledButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.fingerprint_rounded, size: 20),
                            label: const Text(
                              'Разблокировать биометрией',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.password_rounded, size: 18),
                            label: const Text(
                              'Войти по мастер-паролю',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          TextButton(
                            onPressed: () {},
                            child: Text(
                              'Выйти из профиля',
                              style: TextStyle(color: theme.colorScheme.error, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/screen4_security.png'),
      );

      copyToDestination('screen4_security.png', 'screen4_security.png');
    });
  });
}

Widget _buildCalendarDay(BuildContext context, String dayOfWeek, String dayNum, bool isSelected) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    width: 44,
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: isSelected ? cs.primary : cs.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: isSelected ? cs.primary : cs.outlineVariant),
    ),
    child: Column(
      children: [
        Text(
          dayOfWeek,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isSelected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dayNum,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isSelected ? cs.onPrimary : cs.onSurface,
          ),
        ),
      ],
    ),
  );
}

Widget _buildFilterTab(BuildContext context, String label, String count, bool isSelected, Color activeColor) {
  final cs = Theme.of(context).colorScheme;
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: isSelected ? activeColor.withValues(alpha: 0.1) : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? activeColor : cs.outlineVariant,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected ? activeColor : cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isSelected ? activeColor : cs.onSurface,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildInventoryCard(
  BuildContext context, {
  required String name,
  required String substance,
  required String form,
  required String remaining,
  required String expiry,
  required String badgeText,
  required Color badgeColor,
  required Color badgeBg,
  required Color badgeTextColor,
  bool isRx = false,
  bool highlightBorder = false,
  Widget? specialNote,
  Widget? actionWidget,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: highlightBorder ? badgeColor : cs.outlineVariant,
        width: highlightBorder ? 1.5 : 1.0,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      if (isRx) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Rx',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Действ. в-во: $substance • $form',
                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    expiry,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: highlightBorder ? badgeColor : cs.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  remaining,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (specialNote != null) ...[
          specialNote,
        ],
        if (actionWidget != null) ...[
          const SizedBox(height: 8),
          actionWidget,
        ],
      ],
    ),
  );
}

Widget _buildSecurityRow({
  required IconData icon,
  required String title,
  required String value,
  required ColorScheme cs,
}) {
  return Row(
    children: [
      Icon(icon, size: 16, color: cs.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurface),
            ),
          ],
        ),
      ),
    ],
  );
}
