import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medical_note.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'toast_helper.dart';

class AddNoteSheet extends StatefulWidget {
  const AddNoteSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AddNoteSheet(),
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

  // Voice dictation simulation state
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  late AnimationController _waveformController;

  final List<String> _sampleDictations = [
    'Амоксиклав 500 мг 2 раза в день 7 дней, полоскание ромашкой, Нурофен 400 мг при температуре выше 38.5, Гексорал спрей 2 раза в день.',
    'Омепразол 20 мг утром за 30 минут до еды 14 дней, Лоперамид при расстройстве стула, щадящая диета.',
    'Кардиомагнил 75 мг вечером после ужина длительно, контроль артериального давления утром и вечером.',
  ];
  int _dictationSampleIndex = 0;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _toggleDictation() {
    if (_isRecording) {
      _stopDictation();
    } else {
      _startDictation();
    }
  }

  void _startDictation() {
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });
    _waveformController.repeat(reverse: true);

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _recordingSeconds++);
    });
  }

  void _stopDictation() {
    _recordingTimer?.cancel();
    _waveformController.stop();

    // Pick speech sample and insert/append to content
    final sample = _sampleDictations[_dictationSampleIndex % _sampleDictations.length];
    _dictationSampleIndex++;

    setState(() {
      _isRecording = false;
      if (_contentController.text.trim().isEmpty) {
        _contentController.text = sample;
      } else {
        _contentController.text = '${_contentController.text.trim()}\n$sample';
      }
    });

    ToastHelper.show(
      context,
      message: 'Речь врача успешно распознана и расшифрована!',
      icon: '🎙️',
    );
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
    final state = context.watch<AppState>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentText = _contentController.text;
    final previewMatches = MedicalNote.parseAndMatch(currentText, state.medicines);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
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
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.note_alt_outlined,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Новое назначение врача',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Form Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              children: [
                // 1. Specialty Chips
                const Text(
                  'СПЕЦИАЛЬНОСТЬ ВРАЧА',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
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
                          selectedColor: AppColors.primarySurface,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.primaryDeep : AppColors.textSecondary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : AppColors.border,
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
                          const Text(
                            'ВРАЧ / КЛИНИКА',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _doctorController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Иванов А. В.',
                              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary),
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
                          const Text(
                            'ДИАГНОЗ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _diagnosisController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'ОРВИ, фарингит',
                              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary),
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
                    const Text(
                      'РЕЦЕПТ И НАЗНАЧЕНИЯ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      _isRecording ? 'Запись: 00:${_recordingSeconds.toString().padLeft(2, '0')}' : 'Голосовой ввод',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _isRecording ? Colors.red.shade700 : AppColors.primaryHover,
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
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Слушаю врача... говорите назначения',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _stopDictation,
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
                                    color: Colors.red.withValues(alpha: 0.6 + 0.4 * ((_waveformController.value + phase) % 1.0)),
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
                      style: const TextStyle(fontSize: 13, height: 1.4),
                      decoration: InputDecoration(
                        hintText: 'Введите текст назначений или нажмите микрофон для записи диктовки врача...',
                        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.fromLTRB(14, 14, 50, 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.primary),
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
                            color: _isRecording ? Colors.red : AppColors.primarySurface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isRecording ? Colors.red : AppColors.primaryBorder,
                            ),
                          ),
                          child: Icon(
                            _isRecording ? Icons.mic_off : Icons.mic,
                            size: 20,
                            color: _isRecording ? Colors.white : AppColors.primaryHover,
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
                      const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'РАСПОЗНАННЫЕ ЛЕКАРСТВА И НАЛИЧИЕ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppColors.textMuted,
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
                      badgeBg = const Color(0xFFF0FDF4);
                      badgeBorder = const Color(0xFFBBF7D0);
                      badgeText = const Color(0xFF15803D);
                      statusLabel = '🟢 Есть в наличии: ${item.locationInfo}';
                    } else if (item.isLowStock) {
                      badgeBg = const Color(0xFFFFFBEB);
                      badgeBorder = const Color(0xFFFDE68A);
                      badgeText = const Color(0xFFB45309);
                      statusLabel = '🟡 Мало: ${item.locationInfo}';
                    } else {
                      badgeBg = const Color(0xFFFEF2F2);
                      badgeBorder = const Color(0xFFFECACA);
                      badgeText = const Color(0xFFB91C1C);
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
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFB91C1C),
                                elevation: 0,
                                side: const BorderSide(color: Color(0xFFFECACA)),
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
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
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
