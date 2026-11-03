import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/toast_helper.dart';

class FamilyMemberFormSheet extends StatefulWidget {
  final Profile? profile;

  const FamilyMemberFormSheet({super.key, this.profile});

  static Future<void> show(BuildContext context, {Profile? profile}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FamilyMemberFormSheet(profile: profile),
    );
  }

  @override
  State<FamilyMemberFormSheet> createState() => _FamilyMemberFormSheetState();
}

class _FamilyMemberFormSheetState extends State<FamilyMemberFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _allergyInputController;
  late final TextEditingController _chronicInputController;

  late String _selectedRole;
  DateTime? _selectedBirthDate;
  late List<String> _allergies;
  late List<String> _chronicDiseases;
  bool _isLoading = false;

  final List<String> _roles = [
    'Мама',
    'Папа',
    'Ребёнок',
    'Бабушка',
    'Дедушка',
    'Родственник',
  ];

  final List<String> _commonAllergies = [
    'Пенициллины',
    'Аспирин',
    'Лактоза',
    'Сульфаниламиды',
    'Парацетамол',
  ];

  final List<String> _commonChronic = [
    'Гипертензия',
    'Сахарный диабет',
    'Астма',
    'Гастрит',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p?.name ?? '');
    _allergyInputController = TextEditingController();
    _chronicInputController = TextEditingController();

    _selectedRole = p?.role ?? 'Мама';
    if (!_roles.contains(_selectedRole)) {
      _selectedRole = 'Родственник';
    }

    if (p?.birthDate != null && p!.birthDate!.isNotEmpty) {
      try {
        final parts = p.birthDate!.split('-');
        if (parts.length == 3) {
          _selectedBirthDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      } catch (_) {}
    }

    _allergies = List<String>.from(p?.allergies ?? []);

    // Parse chronic diseases from notes if present
    _chronicDiseases = [];
    if (p != null && p.notes.isNotEmpty && !p.notes.contains('Владелец')) {
      for (final item in p.notes.split(',')) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty && !_roles.contains(trimmed)) {
          _chronicDiseases.add(trimmed);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _allergyInputController.dispose();
    _chronicInputController.dispose();
    super.dispose();
  }

  void _addAllergy(String allergen) {
    final clean = allergen.trim();
    if (clean.isEmpty) return;
    if (!_allergies.any((a) => a.toLowerCase() == clean.toLowerCase())) {
      setState(() {
        _allergies.add(clean);
        _allergyInputController.clear();
      });
    }
  }

  void _removeAllergy(String allergen) {
    setState(() {
      _allergies.removeWhere((a) => a.toLowerCase() == allergen.toLowerCase());
    });
  }

  void _addChronic(String disease) {
    final clean = disease.trim();
    if (clean.isEmpty) return;
    if (!_chronicDiseases.any((d) => d.toLowerCase() == clean.toLowerCase())) {
      setState(() {
        _chronicDiseases.add(clean);
        _chronicInputController.clear();
      });
    }
  }

  void _removeChronic(String disease) {
    setState(() {
      _chronicDiseases.removeWhere((d) => d.toLowerCase() == disease.toLowerCase());
    });
  }

  Future<void> _pickBirthDate() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (ctx, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: cs.copyWith(
              primary: cs.primary,
              onPrimary: cs.onPrimary,
              onSurface: cs.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final state = context.read<AppState>();
    final isEditing = widget.profile != null;

    try {
      final notesText = _chronicDiseases.isNotEmpty
          ? _chronicDiseases.join(', ')
          : _selectedRole;

      if (isEditing) {
        await state.updateProfile(
          id: widget.profile!.id,
          name: _nameController.text.trim(),
          role: _selectedRole,
          birthDate: _selectedBirthDate,
          allergies: _allergies,
          notes: notesText,
        );
      } else {
        await state.addProfile(
          name: _nameController.text.trim(),
          role: _selectedRole,
          birthDate: _selectedBirthDate,
          allergies: _allergies,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop();
      ToastHelper.show(
        context,
        message: isEditing
            ? 'Профиль «${_nameController.text.trim()}» обновлен!'
            : 'Член семьи «${_nameController.text.trim()}» добавлен!',
        icon: '👤',
      );
    } catch (e) {
      if (!mounted) return;
      ToastHelper.show(
        context,
        message: 'Ошибка при сохранении профиля: $e',
        icon: '❌',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d.$m.$y';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.profile != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('👤', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Редактирование профиля' : 'Новый член семьи',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Медицинская карта и профиль',
                        style: TextStyle(
                          fontSize: 11,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),

          // Form fields list
          Flexible(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // 1. Full name
                  Text(
                    'ИМЯ ИЛИ ПСЕВДОНИМ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Например: Анна или Миша (Сын)',
                      hintStyle: TextStyle(fontSize: 12, color: textMuted),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Введите имя члена семьи';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // 2. Role in family
                  Text(
                    'РОЛЬ В СЕМЬЕ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _roles.map((r) {
                      final isSel = _selectedRole == r;
                      return ChoiceChip(
                        label: Text(r),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) setState(() => _selectedRole = r);
                        },
                        selectedColor: cs.primaryContainer,
                        backgroundColor: cs.surfaceContainerHighest,
                        side: BorderSide(
                          color: isSel ? cs.primary : cs.outlineVariant,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? cs.primary : textSecondary,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // 3. Date of birth
                  Text(
                    'ДАТА РОЖДЕНИЯ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickBirthDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 16, color: cs.primary),
                              const SizedBox(width: 8),
                              Text(
                                _selectedBirthDate != null
                                    ? _formatDate(_selectedBirthDate!)
                                    : 'Указать дату рождения',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedBirthDate != null
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _selectedBirthDate != null
                                      ? cs.onSurface
                                      : textMuted,
                                ),
                              ),
                            ],
                          ),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: textMuted),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 4. Allergies Block (Critical for CDS Check)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: semantic.dangerBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: semantic.dangerBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: semantic.dangerText),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'АЛЛЕРГИИ И НЕПЕРЕНОСИМОСТИ (CDS)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: semantic.dangerText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Система автоматически предупредит при назначении опасных или несовместимых препаратов.',
                          style: TextStyle(fontSize: 10, color: textSecondary),
                        ),
                        const SizedBox(height: 10),

                        // Input allergen
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _allergyInputController,
                                style: TextStyle(fontSize: 12, color: cs.onSurface),
                                decoration: InputDecoration(
                                  hintText: '+ Добавить аллерген...',
                                  hintStyle: TextStyle(fontSize: 11, color: textMuted),
                                  filled: true,
                                  fillColor: cs.surface,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: semantic.dangerBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: semantic.dangerBorder),
                                  ),
                                ),
                                onSubmitted: (val) => _addAllergy(val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: semantic.danger,
                                foregroundColor: cs.onError,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _addAllergy(_allergyInputController.text),
                              child: const Text('+', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Common presets
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: _commonAllergies.map((a) {
                            return ActionChip(
                              label: Text('+ $a', style: const TextStyle(fontSize: 9)),
                              backgroundColor: cs.surface,
                              side: BorderSide(color: semantic.dangerBorder),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              onPressed: () => _addAllergy(a),
                            );
                          }).toList(),
                        ),

                        if (_allergies.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _allergies.map((allergy) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cs.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: semantic.danger, width: 1.2),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('⚠️ ', style: TextStyle(fontSize: 9)),
                                    Text(
                                      allergy,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: semantic.dangerText,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _removeAllergy(allergy),
                                      child: Icon(Icons.close, size: 14, color: semantic.danger),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 5. Chronic conditions block
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: semantic.warningBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: semantic.warningBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.monitor_heart_outlined, size: 16, color: semantic.warningText),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'ХРОНИЧЕСКИЕ ЗАБОЛЕВАНИЯ',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: semantic.warningText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _chronicInputController,
                                style: TextStyle(fontSize: 12, color: cs.onSurface),
                                decoration: InputDecoration(
                                  hintText: '+ Добавить заболевание...',
                                  hintStyle: TextStyle(fontSize: 11, color: textMuted),
                                  filled: true,
                                  fillColor: cs.surface,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: semantic.warningBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: semantic.warningBorder),
                                  ),
                                ),
                                onSubmitted: (val) => _addChronic(val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: semantic.warning,
                                foregroundColor: cs.onPrimary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _addChronic(_chronicInputController.text),
                              child: const Text('+', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Presets
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: _commonChronic.map((d) {
                            return ActionChip(
                              label: Text('+ $d', style: const TextStyle(fontSize: 9)),
                              backgroundColor: cs.surface,
                              side: BorderSide(color: semantic.warningBorder),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              onPressed: () => _addChronic(d),
                            );
                          }).toList(),
                        ),

                        if (_chronicDiseases.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _chronicDiseases.map((disease) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cs.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: semantic.warningBorder, width: 1.2),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🩺 ', style: TextStyle(fontSize: 9)),
                                    Text(
                                      disease,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: semantic.warningText,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _removeChronic(disease),
                                      child: Icon(Icons.close, size: 14, color: semantic.warningText),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isLoading ? null : _saveProfile,
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                            )
                          : const Text(
                              'Сохранить профиль',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
