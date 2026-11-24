import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/models/medicine.dart';
import 'package:frontend/models/profile.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/storage_service.dart';
import 'package:frontend/widgets/intake_course_wizard.dart';
import 'package:frontend/widgets/safety_alert_banner.dart';

class MockStorageService extends StorageService {}

class TestAppState extends AppState {
  TestAppState() : super(apiService: ApiService(baseUrl: 'http://localhost:8000', storageService: MockStorageService(), isMockMode: true));

  final List<Profile> _testProfiles = [
    const Profile(
      id: 1,
      name: 'Анна',
      role: 'Владелец',
      avatar: '👩',
      subtitle: 'Владелец',
      allergies: [],
    ),
    const Profile(
      id: 2,
      name: 'Миша',
      role: 'Ребёнок',
      avatar: '👦',
      subtitle: 'Сын',
      allergies: ['пенициллины'],
    ),
  ];

  final List<Medicine> _testMedicines = [
    const Medicine(
      id: 10,
      boxId: 1,
      name: 'Амоксициллин',
      substance: 'Амоксициллин',
      form: 'Таблетки',
      remaining: 20,
      total: 20,
      expiry: '2027-12-31',
      status: 'ok',
      allergenTags: ['penicillin'],
    ),
  ];

  @override
  List<Profile> get profiles => _testProfiles;

  @override
  List<Medicine> get medicines => _testMedicines;

  @override
  int? get selectedProfileId => 1;

  @override
  Future<Map<String, dynamic>> checkSafety({
    required int profileId,
    int? medicineId,
    int? referenceMedicineId,
  }) async {
    // Симулируем сетевую ошибку / таймаут при проверке через бэкенд
    throw Exception('Connection timeout (CDS offline)');
  }
}

void main() {
  testWidgets('DEF-55: Wizard shows on-device allergy alert on Step 2 and Step 5 for allergic patient', (tester) async {
    final appState = TestAppState();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: IntakeCourseWizard(
              initialMedicine: appState.medicines.first,
              initialProfileId: 1,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Переходим на Шаг 2
    final nextBtn = find.text('Далее →');
    expect(nextBtn, findsOneWidget);
    await tester.tap(nextBtn);
    await tester.pumpAndSettle();

    // Проверяем, что мы на шаге 2
    expect(find.text('КТО БУДЕТ ПРИНИМАТЬ:'), findsOneWidget);

    // До клика на Мишу у Анны нет аллергии -> баннера с критическим предупреждением нет
    expect(find.textContaining('аллергия на пенициллины'), findsNothing);

    // Выбираем Мишу (id 2) с аллергией на пенициллины
    final mishaChip = find.text('Миша');
    expect(mishaChip, findsOneWidget);
    await tester.tap(mishaChip);
    await tester.pumpAndSettle();

    // На Шаге 2 ОБЯЗАН отобразиться SafetyAlertBanner с предупреждением об аллергии (On-Device CDS)
    expect(find.byType(SafetyAlertBanner), findsOneWidget);
    expect(find.textContaining('аллергия на пенициллины'), findsOneWidget);

    // Переходим далее до Шага 5
    await tester.tap(find.text('Далее →')); // Step 3
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее →')); // Step 4
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее →')); // Step 5
    await tester.pumpAndSettle();

    // Проверяем, что на Шаге 5 баннер предупреждения также отображается
    expect(find.text('ИТОГОВОЕ НАЗНАЧЕНИЕ:'), findsOneWidget);
    expect(find.byType(SafetyAlertBanner), findsOneWidget);
    expect(find.textContaining('аллергия на пенициллины'), findsOneWidget);

    // При попытке создать курс с критическим риском аллергии появляется диалог подтверждения
    final submitBtn = find.text('Создать курс приёма');
    expect(submitBtn, findsOneWidget);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(find.text('Критический риск для пациента'), findsOneWidget);
    expect(find.textContaining('Вы действительно уверены'), findsOneWidget);
  });
}
