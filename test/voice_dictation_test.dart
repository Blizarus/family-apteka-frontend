import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/storage_service.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/widgets/add_note_sheet.dart';

class FakeSpeechToText extends SpeechToText {
  bool shouldInitSucceed;
  SpeechErrorListener? mockErrorListener;
  SpeechStatusListener? mockStatusListener;
  SpeechResultListener? resultListener;
  bool _mockIsListening = false;
  bool listenCalled = false;
  bool stopCalled = false;

  FakeSpeechToText({this.shouldInitSucceed = true}) : super.withMethodChannel();

  @override
  bool get isListening => _mockIsListening;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    mockErrorListener = onError;
    mockStatusListener = onStatus;
    return shouldInitSucceed;
  }

  @override
  Future<List<LocaleName>> locales() async {
    return [LocaleName('ru_RU', 'Русский')];
  }

  @override
  Future<LocaleName?> systemLocale() async {
    return LocaleName('ru_RU', 'Русский');
  }

  @override
  Future<dynamic> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    listenCalled = true;
    _mockIsListening = true;
    resultListener = onResult;
    mockStatusListener?.call('listening');
    return true;
  }

  @override
  Future<dynamic> stop() async {
    stopCalled = true;
    _mockIsListening = false;
    mockStatusListener?.call('notListening');
    return true;
  }

  void emitResult(String words, {bool isFinal = false}) {
    final result = SpeechRecognitionResult.init(
      [SpeechRecognitionWords(words, [words], 0.95)],
      isFinal ? ResultType.finalResult : ResultType.partial,
    );
    resultListener?.call(result);
  }

  void emitStatus(String status) {
    if (status == 'notListening' || status == 'done') {
      _mockIsListening = false;
    }
    mockStatusListener?.call(status);
  }

  void emitError(String errorMsg, {bool permanent = false}) {
    mockErrorListener?.call(SpeechRecognitionError(errorMsg, permanent));
  }
}

Widget createTestApp({required Widget child, AppState? appState}) {
  final storage = StorageService();
  final apiService = ApiService(isMockMode: true, storageService: storage);
  final state = appState ?? AppState(apiService: apiService);
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AddNoteSheet: starts speech recognition on mic tap and captures text', (tester) async {
    final fakeSpeech = FakeSpeechToText(shouldInitSucceed: true);

    await tester.pumpWidget(
      createTestApp(
        child: AddNoteSheet(speechToText: fakeSpeech),
      ),
    );
    await tester.pump();

    // Verify initial mic button is visible
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.text('Голосовой ввод'), findsOneWidget);

    // Tap mic button to start listening
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify listening state
    expect(fakeSpeech.listenCalled, isTrue);
    expect(find.textContaining('Слушаю врача...'), findsOneWidget);
    expect(find.byIcon(Icons.mic_off), findsOneWidget);

    // Emit speech recognition result
    fakeSpeech.emitResult('Амоксиклав 500 мг 2 раза в день 7 дней');
    await tester.pump();

    // Verify text field updated with dictated text
    expect(find.text('Амоксиклав 500 мг 2 раза в день 7 дней'), findsOneWidget);

    // Stop dictation by tapping mic_off button
    await tester.tap(find.byIcon(Icons.mic_off));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fakeSpeech.stopCalled, isTrue);
    expect(find.byIcon(Icons.mic), findsOneWidget);

    // Elapse any active toast timers
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('AddNoteSheet: shows error ToastHelper when speech initialization fails', (tester) async {
    final fakeSpeech = FakeSpeechToText(shouldInitSucceed: false);

    await tester.pumpWidget(
      createTestApp(
        child: AddNoteSheet(speechToText: fakeSpeech),
      ),
    );
    await tester.pump();

    // Tap mic button
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify warning toast is shown
    expect(find.textContaining('Микрофон недоступен: предоставьте разрешение'), findsOneWidget);
    expect(fakeSpeech.listenCalled, isFalse);

    // Elapse toast timer
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('AddNoteSheet: stops recording automatically when status changes to done', (tester) async {
    final fakeSpeech = FakeSpeechToText(shouldInitSucceed: true);

    await tester.pumpWidget(
      createTestApp(
        child: AddNoteSheet(speechToText: fakeSpeech),
      ),
    );
    await tester.pump();

    // Start listening
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.mic_off), findsOneWidget);

    // Device speech recognition engine sends 'done' event (silence timeout)
    fakeSpeech.emitStatus('done');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Recording should be stopped and icon reverted to mic
    expect(find.byIcon(Icons.mic), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
  });
}
