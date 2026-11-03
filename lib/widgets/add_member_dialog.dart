import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'toast_helper.dart';

typedef AddProfileDialog = AddMemberDialog;

class AddMemberDialog extends StatefulWidget {
  const AddMemberDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const AddMemberDialog(),
    );
  }

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _allergyInputController = TextEditingController();

  final List<String> _roles = ['Ребёнок', 'Родственник', 'Родитель'];
  late String _selectedRole;
  DateTime? _selectedBirthDate;
  final List<String> _allergies = [];
  bool _isSubmitting = false;

  final List<String> _quickAllergies = [
    'Пенициллин',
    'Аспирин',
    'Лактоза',
    'Сульфаниламиды',
    'Цитрусовые',
  ];

  @override
  void initState() {
    super.initState();
    _selectedRole = _roles.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _allergyInputController.dispose();
    super.dispose();
  }

  void _addAllergy(String allergy) {
    final clean = allergy.trim();
    if (clean.isNotEmpty && !_allergies.contains(clean)) {
      setState(() {
        _allergies.add(clean);
        _allergyInputController.clear();
      });
    }
  }

  void _removeAllergy(String allergy) {
    setState(() {
      _allergies.remove(allergy);
    });
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2018, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'ВЫБЕРИТЕ ДАТУ РОЖДЕНИЯ',
      cancelText: 'ОТМЕНА',
      confirmText: 'ВЫБРАТЬ',
    );

    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final name = _nameController.text.trim();
      await context.read<AppState>().addProfile(
            name: name,
            role: _selectedRole,
            birthDate: _selectedBirthDate,
            allergies: _allergies,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ToastHelper.show(
          context,
          message: 'Член семьи $name успешно добавлен!',
          icon: '👤',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ToastHelper.show(
          context,
          message: 'Ошибка при сохранении: $e',
          icon: '❌',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

    final birthDateStr = _selectedBirthDate != null
        ? '${_selectedBirthDate!.day.toString().padLeft(2, '0')}.${_selectedBirthDate!.month.toString().padLeft(2, '0')}.${_selectedBirthDate!.year}'
        : null;

    return AlertDialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Icon(
              Icons.person_add_rounded,
              color: cs.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Новый член семьи',
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
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Name field
                Text(
                  'ФИО ИЛИ ИМЯ *',
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
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: cs.onSurface, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Например, Артём (Сын)',
                    hintStyle: TextStyle(fontSize: 13, color: textMuted),
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.primary, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Пожалуйста, введите имя члена семьи';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Role Selector
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
                Row(
                  children: _roles.map((role) {
                    final isSelected = _selectedRole == role;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Text(
                            role,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? cs.onPrimary : textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: cs.primary,
                          backgroundColor: cs.surfaceContainerHighest,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? cs.primary : cs.outlineVariant,
                            ),
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedRole = role);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // Date of Birth
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
                  onTap: _pickBirthDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
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
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              birthDateStr ?? 'Указать дату рождения',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: birthDateStr != null ? FontWeight.w600 : FontWeight.w400,
                                color: birthDateStr != null ? cs.onSurface : textMuted,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedBirthDate != null)
                          InkWell(
                            onTap: () => setState(() => _selectedBirthDate = null),
                            child: Icon(Icons.close_rounded, size: 16, color: textMuted),
                          )
                        else
                          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: textMuted),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Allergies Input
                Text(
                  'АЛЛЕРГИИ И НЕПЕРЕНОСИМОСТИ (МЕДИЦИНСКАЯ КАРТА)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 6),

                // Allergy textfield with add button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _allergyInputController,
                        onSubmitted: _addAllergy,
                        style: TextStyle(color: cs.onSurface, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Введите аллерген (напр. Аспирин)',
                          hintStyle: TextStyle(fontSize: 12, color: textMuted),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: cs.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _addAllergy(_allergyInputController.text),
                      child: const Icon(Icons.add, size: 18),
                    ),
                  ],
                ),

                // Active allergies tags
                if (_allergies.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _allergies.map((allergy) {
                      return Container(
                        padding: const EdgeInsets.only(left: 8, right: 4, top: 4, bottom: 4),
                        decoration: BoxDecoration(
                          color: semantic.dangerBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: semantic.dangerBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚠️ ', style: TextStyle(fontSize: 9)),
                            Text(
                              allergy,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: semantic.dangerText,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _removeAllergy(allergy),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: semantic.dangerText,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Quick presets
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _quickAllergies
                      .where((q) => !_allergies.contains(q))
                      .map((q) => ActionChip(
                            label: Text(
                              '+ $q',
                              style: TextStyle(fontSize: 10, color: textSecondary),
                            ),
                            backgroundColor: cs.surface,
                            side: BorderSide(color: cs.outlineVariant),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            onPressed: () => _addAllergy(q),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text('Отмена', style: TextStyle(color: textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                )
              : const Text('Сохранить профиль', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
