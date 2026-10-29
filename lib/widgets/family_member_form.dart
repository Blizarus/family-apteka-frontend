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
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.profile != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                color: AppColors.borderDarker,
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
                    color: AppColors.primarySurface,
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Медицинская карта и профиль',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Form fields list
          Flexible(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // 1. Full name
                  const Text(
                    'ИМЯ ИЛИ ПСЕВДОНИМ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Например: Анна или Миша (Сын)',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceSubtle,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
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
                  const Text(
                    'РОЛЬ В СЕМЬЕ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
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
                        selectedColor: AppColors.primarySurface,
                        backgroundColor: AppColors.surfaceSubtle,
                        side: BorderSide(
                          color: isSel ? AppColors.primary : AppColors.border,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? AppColors.primaryHover : AppColors.textSecondary,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // 3. Date of birth
                  const Text(
                    'ДАТА РОЖДЕНИЯ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickBirthDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 16, color: AppColors.primaryHover),
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
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 4. Allergies Block (Critical for CDS Check)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusExpiredBg.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.statusExpiredBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.statusExpiredText),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'АЛЛЕРГИИ И НЕПЕРЕНОСИМОСТИ (CDS)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: AppColors.statusExpiredText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Система автоматически предупредит при назначении опасных или несовместимых препаратов.',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),

                        // Input allergen
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _allergyInputController,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: '+ Добавить аллерген...',
                                  hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.statusExpiredBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.statusExpiredBorder),
                                  ),
                                ),
                                onSubmitted: (val) => _addAllergy(val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                foregroundColor: Colors.white,
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
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: AppColors.statusExpiredBorder),
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.danger, width: 1.2),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('⚠️ ', style: TextStyle(fontSize: 9)),
                                    Text(
                                      allergy,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.statusExpiredText,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _removeAllergy(allergy),
                                      child: const Icon(Icons.close, size: 14, color: AppColors.danger),
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
                      color: AppColors.statusExpiringBg.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.statusExpiringBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.monitor_heart_outlined, size: 16, color: AppColors.statusExpiringText),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'ХРОНИЧЕСКИЕ ЗАБОЛЕВАНИЯ',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: AppColors.statusExpiringText,
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
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: '+ Добавить заболевание...',
                                  hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.statusExpiringBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.statusExpiringBorder),
                                  ),
                                ),
                                onSubmitted: (val) => _addChronic(val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.statusExpiringText,
                                foregroundColor: Colors.white,
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
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: AppColors.statusExpiringBorder),
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.statusExpiringBorder, width: 1.2),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🩺 ', style: TextStyle(fontSize: 9)),
                                    Text(
                                      disease,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.statusExpiringText,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _removeChronic(disease),
                                      child: const Icon(Icons.close, size: 14, color: AppColors.statusExpiringText),
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
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isLoading ? null : _saveProfile,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
