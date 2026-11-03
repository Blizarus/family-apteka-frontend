import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/barcode_scanner_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BarcodeScannerSheet Diagnostic & Resilience Tests (Part A)', () {
    testWidgets('1. Sheet renders manual entry, test barcode and gallery action buttons', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BarcodeScannerSheet(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Check header items
      expect(find.text('EAN-13 / DataMatrix'), findsOneWidget);

      // Verify gallery picker button exists
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);

      // Verify quick test code button exists
      expect(find.textContaining('4601234567890'), findsOneWidget);
    });

    testWidgets('2. Submitting manual code pops Navigator with code value', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      String? returnedCode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  returnedCode = await BarcodeScannerSheet.show(ctx);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Tap to open sheet
      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Tap test barcode button
      final testBtn = find.textContaining('Тестовый штрихкод');
      expect(testBtn, findsOneWidget);
      await tester.tap(testBtn);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(returnedCode, '4601234567890');
    });
  });
}
