import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/medical_note.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'toast_helper.dart';

class AddNoteSheet extends StatefulWidget {
  final SpeechToText? speechToText;

  const AddNoteSheet({super.key, this.speechToText});

  static Future<void> show(BuildContext context, {SpeechToText? speechToText}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddNoteSheet(speechToText: speechToText),
    );
  }

  @override
  State<AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends State<AddNoteSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _doctorController =
      TextEditingController(text: 'Иванов А. В.');
  final TextEditingController _diagnosisController =
      TextEditingController(text: 'ОРВИ, фарингит');
  final TextEditingController _contentController = TextEditingController();

  String _selectedSpecialty = 'Терапевт';
  final List<String> _specialties = [
    'Терапевт',
    'Педиатр',
    'ЛОР',
    'Кардиолог',
    'Невролог',
    'Гастроэнтеролог',
  ];

  // Speech-to-text recording state
  late final SpeechToText _speech;
  bool _speechInitialized = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  late AnimationController _waveformController;
  String _baseTextBeforeDictation = '';

  @override
  void initState() {
    super.initState();
    _speech = widget.speechToText ?? SpeechToText();
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _waveformController.dispose();
    _doctorController.dispose();
    _diagnosisController.dispose();
    _contentController.dispose();
    try {
      if (_speech.isListening) {
        _speech.stop();
      }
    } catch (_) {}
    super.dispose();
  }

  Future<void> _toggleDictation() async {
    if (_isRecording) {
      await _stopDictation(showSuccessToast: true);
    } else {
      await _startDictation();
    }
  }

  Future<void> _startDictation() async {
    try {
      if (!_speechInitialized) {
        final available = await _speech.initialize(
          onError: _onSpeechError,
          onStatus: _onSpeechStatus,
        );
        _speechInitialized = available;
        if (!available) {
          if (mounted) {
            ToastHelper.show(
              context,
              message: 'Микрофон недоступен: предоставьте разрешение в настройках или введите текст вручную',
              icon: '🎙️',
              isError: true,
            );
          }
          return;
        }
      }

      _baseTextBeforeDictation = _contentController.text.trim();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });
      _waveformController.repeat(reverse: true);

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _recordingSeconds++);
      });

      String? targetLocaleId;
      try {
        final systemLoc = await _speech.systemLocale();
        final locales = await _speech.locales();
        final hasRu = locales.any((l) => l.localeId.toLowerCase().startsWith('ru'));
        if (hasRu) {
          targetLocaleId = locales.firstWhere((l) => l.localeId.toLowerCase().startsWith('ru')).localeId;
        } else if (systemLoc != null) {
          targetLocaleId = systemLoc.localeId;
        }
      } catch (_) {}

      await _speech.listen(
        onResult: _onSpeechResult,
        listenOptions: SpeechListenOptions(
          localeId: targetLocaleId,
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      await _stopDictation(showSuccessToast: false);
      if (mounted) {
        ToastHelper.show(
          context,
          message: 'Ошибка запуска распознавания речи: $e',
          icon: '⚠️',
          isError: true,
        );
      }
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final words = result.recognizedWords.trim();
    if (words.isEmpty) return;

    setState(() {
      if (_baseTextBeforeDictation.isEmpty) {
        _contentController.text = words;
      } else {
        _contentController.text = '$_baseTextBeforeDictation\n$words';
      }
      _contentController.selection = TextSelection.collapsed(
        offset: _contentController.text.length,
      );
    });
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == 'notListening' || status == 'done') {
      if (_isRecording) {
        _stopDictation(showSuccessToast: false);
      }
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    _stopDictation(showSuccessToast: false);
    ToastHelper.show(
      context,
      message: 'Ошибка распознавания: ${error.errorMsg}',
      icon: '⚠️',
      isError: true,
    );
  }

  Future<void> _stopDictation({bool showSuccessToast = true}) async {
    _recordingTimer?.cancel();
    _waveformController.stop();

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isRecording = false;
    });

    if (showSuccessToast && _contentController.text.trim().isNotEmpty) {
      ToastHelper.show(
        context,
        message: 'Речь врача успешно распознана и расшифрована!',
        icon: '🎙️',
      );
    }
  }

  void _saveNote() {
    final state = context.read<AppState>();
    final content = _contentController.text.trim();
    final doctor = _doctorController.text.trim();
    final diagnosis = _diagnosisController.text.trim();

    if (content.isEmpty) {
      ToastHelper.show(
        context,
        message: 'Укажите назначения врача или воспользуйтесь диктовкой',
        icon: '⚠️',
        isError: true,
      );
      return;
    }

    final profileId = state.selectedProfileId ?? state.profiles.firstOrNull?.id ?? 1;
    final matchedMedicines = MedicalNote.parseAndMatch(content, state.medicines);

    final note = MedicalNote(
      id: DateTime.now().millisecondsSinceEpoch,
      profileId: profileId,
      doctorName: doctor.isNotEmpty ? doctor : 'Врач',
      specialty: _selectedSpecialty,
      clinic: 'Городская поликлиника',
      diagnosis: diagnosis.isNotEmpty ? diagnosis : 'Консультация',
      date: DateTime.now(),
      content: content,
      prescribedMedicines: matchedMedicines,
      isAudioDictated: true,
    );

    state.addNote(note);
    Navigator.of(context).pop();

    ToastHelper.show(
      context,
      message: 'Назначение сохранено. Сопоставлено с аптечкой!',
      icon: '📝',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

    final state = context.watch<AppState>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentText = _contentController.text;
    final previewMatches = MedicalNote.parseAndMatch(currentText, state.medicines);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.note_alt_outlined,
                      color: cs.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Новое назначение врача',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: textMuted),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: cs.outlineVariant),

          // Form Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              children: [
                // 1. Specialty Chips
                Text(
                  'СПЕЦИАЛЬНОСТЬ ВРАЧА',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _specialties.map((spec) {
                      final isSelected = _selectedSpecialty == spec;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(spec),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _selectedSpecialty = spec);
                          },
                          selectedColor: cs.primaryContainer,
                          backgroundColor: cs.surface,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? cs.onPrimaryContainer : textSecondary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? cs.primary : cs.outlineVariant,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Doctor Name & Diagnosis Row
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ВРАЧ / КЛИНИКА',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _doctorController,
                            style: TextStyle(fontSize: 13, color: cs.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Иванов А. В.',
                              hintStyle: TextStyle(fontSize: 12, color: textMuted),
                              isDense: true,
                              filled: true,
                              fillColor: cs.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: cs.outlineVariant),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: cs.outlineVariant),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: cs.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ДИАГНОЗ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _diagnosisController,
                            style: TextStyle(fontSize: 13, color: cs.onSurface),
                            decoration: InputDecoration(
                              hintText: 'ОРВИ, фарингит',
                              hintStyle: TextStyle(fontSize: 12, color: textMuted),
                              isDense: true,
                              filled: true,
                              fillColor: cs.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: cs.outlineVariant),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: cs.outlineVariant),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: cs.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Prescription & Recommendations with Dictation Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'РЕЦЕПТ И НАЗНАЧЕНИЯ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: textMuted,
                      ),
                    ),
                    Text(
                      _isRecording ? 'Запись: 00:${_recordingSeconds.toString().padLeft(2, '0')}' : 'Голосовой ввод',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _isRecording ? semantic.danger : cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Dictation Live Waveform Panel (when recording)
                if (_isRecording)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: semantic.dangerBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: semantic.dangerBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: semantic.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Слушаю врача... говорите назначения',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: semantic.dangerText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: semantic.danger,
                                foregroundColor: cs.onError,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _stopDictation(showSuccessToast: true),
                              icon: const Icon(Icons.stop, size: 14),
                              label: const Text('Стоп', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Pulsing Waveform visualizer
                        AnimatedBuilder(
                          animation: _waveformController,
                          builder: (context, child) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(16, (i) {
                                final phase = (i / 16.0);
                                final height = 8 + 24 * ((_waveformController.value + phase) % 1.0);
                                return Container(
                                  width: 4,
                                  height: height,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: semantic.danger.withValues(alpha: 0.6 + 0.4 * ((_waveformController.value + phase) % 1.0)),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                // Text field with integrated Mic action button
                Stack(
                  children: [
                    TextField(
                      controller: _contentController,
                      onChanged: (val) => setState(() {}),
                      maxLines: 5,
                      style: TextStyle(fontSize: 13, height: 1.4, color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Введите текст назначений или нажмите микрофон для записи диктовки врача...',
                        hintStyle: TextStyle(fontSize: 12, color: textMuted),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.fromLTRB(14, 14, 50, 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: cs.primary),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(100),
                        onTap: _toggleDictation,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isRecording ? semantic.danger : cs.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isRecording ? semantic.danger : cs.outlineVariant,
                            ),
                          ),
                          child: Icon(
                            _isRecording ? Icons.mic_off : Icons.mic,
                            size: 20,
                            color: _isRecording ? cs.onError : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Real-time Matched Medicines Preview
                if (previewMatches.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: cs.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'РАСПОЗНАННЫЕ ЛЕКАРСТВА И НАЛИЧИЕ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...previewMatches.map((item) {
                    Color badgeBg;
                    Color badgeBorder;
                    Color badgeText;
                    String statusLabel;

                    if (item.isInStock) {
                      badgeBg = semantic.successBg;
                      badgeBorder = semantic.successBorder;
                      badgeText = semantic.successText;
                      statusLabel = '🟢 Есть в наличии: ${item.locationInfo}';
                    } else if (item.isLowStock) {
                      badgeBg = semantic.warningBg;
                      badgeBorder = semantic.warningBorder;
                      badgeText = semantic.warningText;
                      statusLabel = '🟡 Мало: ${item.locationInfo}';
                    } else {
                      badgeBg = semantic.dangerBg;
                      badgeBorder = semantic.dangerBorder;
                      badgeText = semantic.dangerText;
                      statusLabel = '🔴 Нет в аптечке';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: badgeText,
                                  ),
                                ),
                                Text(
                                  statusLabel,
                                  style: TextStyle(fontSize: 10, color: badgeText),
                                ),
                              ],
                            ),
                          ),
                          if (item.isMissing)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.surface,
                                foregroundColor: semantic.dangerText,
                                elevation: 0,
                                side: BorderSide(color: semantic.dangerBorder),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                state.addToShoppingList(item.name);
                                ToastHelper.show(
                                  context,
                                  message: '«${item.name}» добавлен в список покупок',
                                  icon: '🛒',
                                );
                              },
                              child: const Text('+ В покупки', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                ],

                // 5. Submit Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _saveNote,
                  child: const Text(
                    'Сохранить назначение',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
