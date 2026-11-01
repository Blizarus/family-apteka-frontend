import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/widgets/medicine_details_sheet.dart';
import 'package:frontend/widgets/add_medicine_sheet.dart';
import 'package:frontend/widgets/add_note_sheet.dart';
import 'package:frontend/widgets/swipeable_prescription_card.dart';
import 'package:frontend/screens/notes_screen.dart';
import 'package:frontend/widgets/expandable_calendar.dart';
import 'package:frontend/widgets/intake_course_wizard.dart';
import 'package:frontend/widgets/quick_intake_sheet.dart';

Widget createTestApp(ApiService apiService) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(apiService: apiService),
      ),
    ],
    child: const FamilyAptekaApp(),
  );
}

Future<void> loginTestUser(WidgetTester tester) async {
  await tester.pumpWidget(createTestApp(ApiService(isMockMode: true)));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();

  await tester.tap(find.text('Войти в аккаунт'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

void main() {
  testWidgets('Screen 1 Today: verifies intakes, snooze and skip dialog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await loginTestUser(tester);

    final now = DateTime.now();
    final weekdays = [
      'ПОНЕДЕЛЬНИК',
      'ВТОРНИК',
      'СРЕДА',
      'ЧЕТВЕРГ',
      'ПЯТНИЦА',
      'СУББОТА',
      'ВОСКРЕСЕНЬЕ'
    ];
    final months = [
      'ЯНВАРЯ',
      'ФЕВРАЛЯ',
      'МАРТА',
      'АПРЕЛЯ',
      'МАЯ',
      'ИЮНЯ',
      'ИЮЛЯ',
      'АВГУСТА',
      'СЕНТЯБРЯ',
      'ОКТЯБРЯ',
      'НОЯБРЯ',
      'ДЕКАБРЯ'
    ];
    final todayTitle = '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';

    expect(find.text('Расписание приёма'), findsOneWidget);
    expect(find.text(todayTitle), findsOneWidget);
    expect(find.text('Принято'), findsWidgets);
    expect(find.text('+15м'), findsWidgets);
    expect(find.text('Пропустить'), findsWidgets);

    // Open skip reason dialog
    await tester.ensureVisible(find.text('Пропустить').first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Пропустить').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Пропуск приёма'), findsOneWidget);
    expect(find.text('Плохое самочувствие / тошнота'), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('Screen 2 Inventory: opens medicine details sheet with instructions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await loginTestUser(tester);

    // Navigate to Inventory Tab
    await tester.tap(find.text('Аптечка'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ИНВЕНТАРЬ АПТЕЧКИ'), findsOneWidget);
    expect(find.text('Домашняя аптечка'), findsOneWidget);
    expect(find.text('Добавить препарат'), findsOneWidget);

    // Tap on medicine to open details sheet
    await tester.tap(find.text('Ибупрофен 400 мг'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('БЕЗОПАСНОСТЬ (CDS)'), findsOneWidget);
    expect(find.text('Проверить совместимость'), findsOneWidget);
    expect(find.text('ОФИЦИАЛЬНАЯ ИНСТРУКЦИЯ'), findsOneWidget);
    expect(find.text('Показания к применению'), findsOneWidget);

    // Close sheet to drain timers
    Navigator.of(tester.element(find.byType(MedicineDetailsSheet))).pop();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('Screen 2 Inventory: opens add medicine sheet', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await loginTestUser(tester);

    // Navigate to Inventory Tab
    await tester.tap(find.text('Аптечка'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Tap FAB "Добавить препарат"
    await tester.tap(find.text('Добавить препарат'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ПРЕПАРАТ И СПРАВОЧНИК'), findsOneWidget);
    expect(find.text('АПТЕЧКА ХРАНЕНИЯ'), findsOneWidget);
    expect(find.text('ЕДИНИЦА ИЗМЕРЕНИЯ'), findsOneWidget);

    // Close sheet
    Navigator.of(tester.element(find.byType(AddMedicineSheet))).pop();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('Screen 3 Notes: verifies 4-tab bar, doctor notes and inventory matching', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await loginTestUser(tester);

    // 4 tabs must be visible: Сегодня, Аптечка, Заметки, Семья
    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('Аптечка'), findsOneWidget);
    expect(find.text('Заметки'), findsOneWidget);
    expect(find.text('Семья'), findsOneWidget);

    // Navigate to Notes Tab (Index 2)
    await tester.tap(find.text('Заметки'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Notes Screen elements
    expect(find.text('Заметки и рецепты'), findsOneWidget);
    expect(find.text('Назначения врачей и синхронизация с аптечкой'), findsOneWidget);
    expect(find.text('Новое назначение'), findsOneWidget);

    // Verify doctor card & stock traffic light
    expect(find.text('СОПОСТАВЛЕНИЕ С АПТЕЧКОЙ'), findsWidgets);
    expect(find.text('Светофор запасов'), findsWidgets);

    // Tap FAB "Новое назначение"
    await tester.tap(find.text('Новое назначение'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Новое назначение врача'), findsOneWidget);
    expect(find.text('РЕЦЕПТ И НАЗНАЧЕНИЯ'), findsOneWidget);
    expect(find.text('Голосовой ввод'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);

    // Test microphone speech dictation
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Слушаю врача... говорите назначения'), findsOneWidget);
    expect(find.text('Стоп'), findsOneWidget);

    // Stop dictation
    await tester.tap(find.text('Стоп'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('РАСПОЗНАННЫЕ ЛЕКАРСТВА И НАЛИЧИЕ'), findsOneWidget);

    // Close sheet
    Navigator.of(tester.element(find.byType(AddNoteSheet))).pop();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('Screen 3 Notes: swipe right archives, undo SnackBar restores, cross-linked purchase turns badge green', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await loginTestUser(tester);

    // Navigate to Notes Tab
    await tester.tap(find.text('Заметки'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify SwipeablePrescriptionCard exists
    expect(find.byType(SwipeablePrescriptionCard), findsWidgets);

    // Test Swipe Right to Archive
    final firstCard = find.byType(SwipeablePrescriptionCard).first;
    final dragPoint = tester.getTopLeft(firstCard) + const Offset(50, 40);
    await tester.dragFrom(dragPoint, const Offset(250, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 7-second Undo SnackBar should appear with "↩️ Отмена"
    expect(find.text('↩️ Отмена'), findsOneWidget);

    // Invoke "↩️ Отмена" action callback directly to restore card
    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    action.onPressed();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Clear snackbars to avoid leftover timers
    ScaffoldMessenger.of(tester.element(find.byType(NotesScreen))).clearSnackBars();
    await tester.pump(const Duration(milliseconds: 200));

    // Test Cross-linked reactive logic (Покупки -> Аптечка -> Рецепт):
    // Switch to shopping tab (using ensureVisible for horizontal scroll)
    await tester.ensureVisible(find.text('🛒 В аптеку'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('🛒 В аптеку'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Список покупок в аптеку'), findsOneWidget);
    expect(find.text('Куплено'), findsWidgets);

    // Tap "Куплено" on the first item (e.g. Гексорал спрей)
    await tester.tap(find.text('Куплено').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Clear snackbars
    ScaffoldMessenger.of(tester.element(find.byType(NotesScreen))).clearSnackBars();
    await tester.pump(const Duration(milliseconds: 200));

    // Switch back to "Активные" tab
    await tester.ensureVisible(find.text('Активные'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Активные'));
    await tester.pump(const Duration(milliseconds: 500));

    // The badge in recipe card is now green "✓ В аптечке"
    expect(find.textContaining('✓ В аптечке'), findsWidgets);
  });

  testWidgets('Screen Auth: 152-FZ consent checkbox and registration mode', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestApp(ApiService(isMockMode: true)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    // Verify auth screen has toggle
    expect(find.text('Вход'), findsOneWidget);
    expect(find.text('Регистрация'), findsOneWidget);

    // Switch to registration mode
    await tester.tap(find.text('Регистрация'));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify registration fields & 152-ФЗ compliance
    expect(find.text('ВАШЕ ИМЯ ИЛИ ПСЕВДОНИМ'), findsOneWidget);
    expect(find.text('ПОДТВЕРЖДЕНИЕ ПАРОЛЯ'), findsOneWidget);
    expect(find.textContaining('152-ФЗ РФ'), findsOneWidget);
    expect(find.text('Облачная синхронизация'), findsOneWidget);
    expect(find.text('Создать защищенный аккаунт'), findsOneWidget);

    // Fill demo credentials
    await tester.ensureVisible(find.text('Заполнить демо-данными'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Заполнить демо-данными'));
    await tester.pump(const Duration(milliseconds: 500));

    // Register button tap
    await tester.ensureVisible(find.text('Создать защищенный аккаунт'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Создать защищенный аккаунт'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // After registration, main screen should be loaded
    expect(find.text('Расписание приёма'), findsOneWidget);
  });

  testWidgets('Screen 4 Family: verifies profiles, allergy tags, online sync banner, and adding new family member', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await loginTestUser(tester);

    // Navigate to Family Tab
    await tester.tap(find.text('Семья'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify header and profiles
    expect(find.text('Семья и профили'), findsOneWidget);
    expect(find.text('Анна'), findsOneWidget);
    expect(find.text('Бабушка (Елена)'), findsOneWidget);
    expect(find.text('Миша (Сын)'), findsOneWidget);

    // Verify medical allergy tag
    expect(find.text('Пенициллин'), findsOneWidget);

    // Verify honest offline sync status banner (Sanctum API & SQLite Roadmap v2)
    expect(find.text('Режим: Онлайн (Sanctum API)'), findsOneWidget);
    expect(find.text('Локальный офлайн-кэш — в разработке (Roadmap v2)'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);

    // Tap "Добавить члена семьи"
    await tester.ensureVisible(find.text('Добавить члена семьи'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Добавить члена семьи'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify modal dialog appeared
    expect(find.text('Новый член семьи'), findsOneWidget);
    expect(find.text('Медицинская карта и профиль'), findsOneWidget);

    // Fill form
    await tester.enterText(find.byType(TextFormField).first, 'Артём (Брат)');
    await tester.pump();

    // Select role
    await tester.tap(find.text('Родственник'));
    await tester.pump();

    // Submit dialog
    await tester.tap(find.text('Сохранить профиль'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify new member is now present in profile list
    expect(find.text('Артём (Брат)'), findsOneWidget);
  });

  testWidgets('Server Config Dialog: long-press on brand opens tester server switcher and updates baseUrl', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final apiService = ApiService(isMockMode: true);
    await tester.pumpWidget(createTestApp(apiService));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    // Long press brand title to trigger developer dialog
    await tester.longPress(find.text('Семейная Аптечка'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify dialog opened
    expect(find.text('Адрес сервера API'), findsOneWidget);
    expect(find.text('Настройки подключения для тестеров'), findsOneWidget);

    // Tap emulator preset
    await tester.tap(find.text('10.0.2.2 (Android Эмулятор)'));
    await tester.pump();

    // Tap Save and Test
    await tester.tap(find.text('Сохранить и проверить связь'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // BaseUrl should now be updated to emulator URL
    expect(apiService.baseUrl, contains('10.0.2.2'));
  });

  testWidgets('Screen 2 Inventory: opens camera barcode scanner and autofills medicine from catalog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await loginTestUser(tester);

    // Navigate to Inventory Tab
    await tester.tap(find.text('Аптечка'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Tap FAB "Добавить препарат"
    await tester.tap(find.text('Добавить препарат'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Scanner button should be visible next to search input
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);

    // Tap scanner button
    await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Barcode scanner modal should be visible
    expect(find.text('EAN-13 / DataMatrix'), findsOneWidget);
    expect(find.text('Тестовый штрихкод: Ибупрофен (4601234567890)'), findsOneWidget);

    // Tap demo barcode button to simulate successful scan
    await tester.tap(find.text('Тестовый штрихкод: Ибупрофен (4601234567890)'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Scanner closes and returns to AddMedicineSheet with autofilled data
    expect(find.textContaining('Ибупрофен'), findsWidgets);
    expect(find.textContaining('Штрихкод: 4601234567890'), findsOneWidget);

    // Close sheet
    Navigator.of(tester.element(find.byType(AddMedicineSheet))).pop();
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('Interactive Calendar & Intake Course Wizard: calendar toggle and multi-step course creation', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await loginTestUser(tester);

    // 1. ExpandableCalendar is displayed
    expect(find.byType(ExpandableCalendar), findsOneWidget);
    expect(find.text('◎ Сегодня'), findsOneWidget);

    // Toggle calendar to Month view
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

    // Collapse back to week view
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

    // 2. Open IntakeCourseWizard via FAB
    expect(find.text('Назначить курс'), findsWidgets);
    await tester.tap(find.text('Назначить курс').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(IntakeCourseWizard), findsOneWidget);
    expect(find.text('ШАГ 1 ИЗ 5'), findsOneWidget);
    expect(find.text('Выбор препарата'), findsOneWidget);

    // Select first medicine in stock (e.g. Ибупрофен 400 мг)
    await tester.tap(find.text('Ибупрофен 400 мг').first);
    await tester.pump(const Duration(milliseconds: 300));

    // Proceed to Step 2
    await tester.tap(find.text('Далее →'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ШАГ 2 ИЗ 5'), findsOneWidget);
    expect(find.text('Пациент и разовая доза'), findsOneWidget);

    // Step 2: change dosage
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    // Proceed to Step 3
    await tester.tap(find.text('Далее →'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ШАГ 3 ИЗ 5'), findsOneWidget);
    expect(find.text('Частота и приём пищи'), findsOneWidget);

    // Step 3: choose frequency chip
    await tester.tap(find.text('3 раза в день'));
    await tester.pump(const Duration(milliseconds: 300));

    // Proceed to Step 4
    await tester.tap(find.text('Далее →'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ШАГ 4 ИЗ 5'), findsOneWidget);
    expect(find.text('Время приёма и уведомления'), findsOneWidget);
    expect(find.text('Напомнить за 15 минут'), findsOneWidget);

    // Proceed to Step 5
    await tester.tap(find.text('Далее →'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ШАГ 5 ИЗ 5'), findsOneWidget);
    expect(find.text('Длительность и подтверждение'), findsOneWidget);
    expect(find.text('Создать курс приёма'), findsOneWidget);

    // Create course
    await tester.tap(find.text('Создать курс приёма'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Sheet should be closed and success message shown
    expect(find.byType(IntakeCourseWizard), findsNothing);
  });

  testWidgets('Quick Intake (PRN): drink now reduces inventory stock and records taken intake on Today screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await loginTestUser(tester);

    // 1. Navigate to Inventory tab
    await tester.tap(find.text('Аптечка'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify initial stock of Ibuprofen is 16
    expect(find.text('Ибупрофен 400 мг'), findsOneWidget);
    expect(find.text('16 / 20 шт.'), findsOneWidget);

    // 2. Tap on Ibuprofen to open details sheet
    await tester.tap(find.text('Ибупрофен 400 мг'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify "Выпить сейчас" button is present
    expect(find.byType(MedicineDetailsSheet), findsOneWidget);
    expect(find.text('Выпить сейчас'), findsOneWidget);

    // 3. Tap "Выпить сейчас"
    await tester.tap(find.text('Выпить сейчас'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // QuickIntakeSheet should be open
    expect(find.byType(QuickIntakeSheet), findsOneWidget);
    expect(find.text('Разовый приём'), findsOneWidget);
    expect(find.textContaining('Остаток: 16'), findsOneWidget);
    expect(find.text('⚡ Боль в животе'), findsOneWidget);

    // Select symptom (default is already ⚡ Боль в животе)
    await tester.tap(find.text('⚡ Боль в животе'));
    await tester.pump(const Duration(milliseconds: 200));

    // 4. Confirm intake
    expect(find.text('⚡ Подтвердить приём'), findsOneWidget);
    await tester.tap(find.text('⚡ Подтвердить приём'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // QuickIntakeSheet closes
    expect(find.byType(QuickIntakeSheet), findsNothing);

    // SnackBar message shown with new remaining 15
    expect(find.textContaining('Остаток: 15'), findsOneWidget);

    // Close details sheet
    Navigator.of(tester.element(find.byType(MedicineDetailsSheet))).pop();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify inventory shows reduced stock (15 / 20 шт.)
    expect(find.text('15 / 20 шт.'), findsOneWidget);

    // 5. Navigate back to "Сегодня" tab
    await tester.tap(find.text('Сегодня'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify intake appears in Today's list with symptom and taken checkmark
    expect(find.textContaining('Боль в животе'), findsWidgets);
    expect(find.text('✓ Принято'), findsWidgets);
  });
}
