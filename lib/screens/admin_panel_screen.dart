import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reference_medicine.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/toast_helper.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _medSearchController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = false;

  List<ReferenceMedicine> _referenceMedicines = [];
  bool _loadingMeds = false;

  String _userSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
      _loadReferenceMedicines();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _medSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final state = context.read<AppState>();
      final users = await state.getAdminUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _loadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingUsers = false);
        ToastHelper.show(
          context,
          message: 'Ошибка загрузки пользователей: $e',
          icon: '⚠️',
          isError: true,
        );
      }
    }
  }

  Future<void> _loadReferenceMedicines([String query = '']) async {
    setState(() => _loadingMeds = true);
    try {
      final state = context.read<AppState>();
      final meds = await state.searchReferenceMedicines(query);
      if (mounted) {
        setState(() {
          _referenceMedicines = meds;
          _loadingMeds = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMeds = false);
        ToastHelper.show(
          context,
          message: 'Ошибка загрузки ГРЛС: $e',
          icon: '⚠️',
          isError: true,
        );
      }
    }
  }

  Future<void> _handleToggleBlockUser(Map<String, dynamic> user) async {
    final state = context.read<AppState>();
    final userId = user['id'] as int;
    final isCurrentlyBlocked = user['is_blocked'] as bool? ?? false;
    final email = user['email'] as String? ?? 'Пользователь';

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

    if (!isCurrentlyBlocked) {
      // Confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Блокировка пользователя',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface),
                ),
              ),
            ],
          ),
          content: Text(
            'Вы действительно хотите заблокировать доступ для $email?\n\n'
            'Все активные Sanctum-токены и сессии пользователя будут немедленно аннулированы.',
            style: TextStyle(fontSize: 13, height: 1.4, color: cs.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Отмена', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: semantic.danger,
                foregroundColor: cs.onError,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Заблокировать'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      try {
        await state.toggleBlockUser(userId, true);
        if (!mounted) return;
        ToastHelper.show(
          context,
          message: 'Пользователь заблокирован, все активные сессии аннулированы',
          icon: '🔒',
          isError: true,
        );
        _loadUsers();
      } catch (e) {
        if (!mounted) return;
        ToastHelper.show(
          context,
          message: 'Ошибка блокировки пользователя: $e',
          icon: '⚠️',
          isError: true,
        );
      }
    } else {
      // Unblock
      try {
        await state.toggleBlockUser(userId, false);
        if (!mounted) return;
        ToastHelper.show(
          context,
          message: 'Пользователь $email успешно разблокирован',
          icon: '✓',
        );
        _loadUsers();
      } catch (e) {
        if (!mounted) return;
        ToastHelper.show(
          context,
          message: 'Ошибка разблокировки пользователя: $e',
          icon: '⚠️',
          isError: true,
        );
      }
    }
  }

  void _showAddMedicineDialog() {
    final formKey = GlobalKey<FormState>();
    final tradeNameController = TextEditingController();
    final innController = TextEditingController();
    final barcodeController = TextEditingController();
    final dosageController = TextEditingController();
    final manufacturerController = TextEditingController(text: 'ОАО Фармстандарт');
    final countryController = TextEditingController(text: 'Россия');
    final packSizeController = TextEditingController(text: '20');
    String selectedForm = 'Таблетки';
    bool isPrescription = false;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: cs.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Text('💊', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Добавить препарат в ГРЛС',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Эталонная запись реестра лекарственных средств (ЛР 2)',
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                      const SizedBox(height: 14),

                      // Торговое наименование
                      TextFormField(
                        controller: tradeNameController,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Торговое наименование *',
                          labelStyle: TextStyle(color: textMuted),
                          hintText: 'Например, Парацетамол-Ультра',
                          hintStyle: TextStyle(color: textMuted),
                          isDense: true,
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
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
                            borderSide: BorderSide(color: cs.primary),
                          ),
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? 'Обязательное поле' : null,
                      ),
                      const SizedBox(height: 12),

                      // МНН
                      TextFormField(
                        controller: innController,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: 'МНН (Действующее вещество) *',
                          labelStyle: TextStyle(color: textMuted),
                          hintText: 'Например, Парацетамол',
                          hintStyle: TextStyle(color: textMuted),
                          isDense: true,
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
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
                            borderSide: BorderSide(color: cs.primary),
                          ),
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? 'Обязательное поле' : null,
                      ),
                      const SizedBox(height: 12),

                      // Штрихкод
                      TextFormField(
                        controller: barcodeController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Штрихкод / EAN-13 *',
                          labelStyle: TextStyle(color: textMuted),
                          hintText: '4601234567890',
                          hintStyle: TextStyle(color: textMuted),
                          prefixIcon: Icon(Icons.qr_code_rounded, size: 18, color: textMuted),
                          isDense: true,
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
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
                            borderSide: BorderSide(color: cs.primary),
                          ),
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? 'Укажите штрихкод' : null,
                      ),
                      const SizedBox(height: 12),

                      // Форма выпуска и Дозировка в строку
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedForm,
                              dropdownColor: cs.surface,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface),
                              decoration: InputDecoration(
                                labelText: 'Форма выпуска',
                                labelStyle: TextStyle(color: textMuted),
                                isDense: true,
                                filled: true,
                                fillColor: cs.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: cs.outlineVariant),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: cs.outlineVariant),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Таблетки', child: Text('Таблетки')),
                                DropdownMenuItem(value: 'Капсулы', child: Text('Капсулы')),
                                DropdownMenuItem(value: 'Спрей', child: Text('Спрей')),
                                DropdownMenuItem(value: 'Сироп', child: Text('Сироп')),
                                DropdownMenuItem(value: 'Мазь', child: Text('Мазь')),
                                DropdownMenuItem(value: 'Ампулы', child: Text('Ампулы')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedForm = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: dosageController,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                              decoration: InputDecoration(
                                labelText: 'Дозировка *',
                                labelStyle: TextStyle(color: textMuted),
                                hintText: '500 мг',
                                hintStyle: TextStyle(color: textMuted),
                                isDense: true,
                                filled: true,
                                fillColor: cs.surfaceContainerHighest,
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
                                  borderSide: BorderSide(color: cs.primary),
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty) ? 'Укажите дозу' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Производитель и Страна
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: manufacturerController,
                              style: TextStyle(fontSize: 13, color: cs.onSurface),
                              decoration: InputDecoration(
                                labelText: 'Производитель',
                                labelStyle: TextStyle(color: textMuted),
                                isDense: true,
                                filled: true,
                                fillColor: cs.surfaceContainerHighest,
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
                                  borderSide: BorderSide(color: cs.primary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: countryController,
                              style: TextStyle(fontSize: 13, color: cs.onSurface),
                              decoration: InputDecoration(
                                labelText: 'Страна',
                                labelStyle: TextStyle(color: textMuted),
                                isDense: true,
                                filled: true,
                                fillColor: cs.surfaceContainerHighest,
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
                                  borderSide: BorderSide(color: cs.primary),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Количество в упаковке и Рецептурный статус
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: packSizeController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(fontSize: 13, color: cs.onSurface),
                              decoration: InputDecoration(
                                labelText: 'Упаковка (ед.)',
                                labelStyle: TextStyle(color: textMuted),
                                isDense: true,
                                filled: true,
                                fillColor: cs.surfaceContainerHighest,
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
                                  borderSide: BorderSide(color: cs.primary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('По рецепту', style: TextStyle(fontSize: 12, color: cs.onSurface)),
                              value: isPrescription,
                              activeColor: cs.primary,
                              onChanged: (val) {
                                setDialogState(() => isPrescription = val ?? false);
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Отмена', style: TextStyle(color: textSecondary)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final payload = {
                    'trade_name': tradeNameController.text.trim(),
                    'inn': innController.text.trim(),
                    'barcode': barcodeController.text.trim(),
                    'dosage_form': selectedForm,
                    'dosage': dosageController.text.trim(),
                    'manufacturer': manufacturerController.text.trim().isNotEmpty
                        ? manufacturerController.text.trim()
                        : 'ОАО Фармстандарт',
                    'country': countryController.text.trim().isNotEmpty
                        ? countryController.text.trim()
                        : 'Россия',
                    'pack_size': int.tryParse(packSizeController.text.trim()) ?? 20,
                    'is_prescription': isPrescription,
                  };

                  final state = context.read<AppState>();
                  try {
                    await state.addReferenceMedicine(payload);
                    if (!dialogCtx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    ToastHelper.show(
                      context,
                      message: 'Препарат успешно добавлен в справочник ГРЛС',
                      icon: '💊',
                    );
                    _loadReferenceMedicines(_medSearchController.text.trim());
                  } catch (e) {
                    if (!mounted) return;
                    ToastHelper.show(
                      context,
                      message: 'Ошибка добавления препарата: $e',
                      icon: '⚠️',
                      isError: true,
                    );
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Сохранить в ГРЛС'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(dynamic dateRaw) {
    if (dateRaw == null) return 'Не указана';
    try {
      final dt = DateTime.parse(dateRaw.toString());
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      final hr = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d.$m.$y в $hr:$min';
    } catch (_) {
      return dateRaw.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Панель администратора',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            Text(
              'Безопасность ИБ • RBAC • ЛР 2',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: cs.primary),
            tooltip: 'Обновить данные',
            onPressed: () {
              if (_tabController.index == 0) {
                _loadUsers();
              } else {
                _loadReferenceMedicines(_medSearchController.text.trim());
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: textSecondary,
          indicatorColor: cs.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(
              icon: Icon(Icons.people_alt_outlined, size: 20),
              text: 'Пользователи',
            ),
            Tab(
              icon: Icon(Icons.menu_book_outlined, size: 20),
              text: 'Справочник ГРЛС',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ==========================================
          // TAB 1: USERS LIST & BLOCK TOGGLE
          // ==========================================
          _buildUsersTab(state, cs, textSecondary, textMuted),

          // ==========================================
          // TAB 2: GRLS REFERENCE MEDICINES & ADD FORM
          // ==========================================
          _buildGrlsTab(cs, textSecondary, textMuted),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          if (_tabController.index == 1) {
            return FloatingActionButton.extended(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Добавить препарат',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              onPressed: _showAddMedicineDialog,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildUsersTab(AppState state, ColorScheme cs, Color textSecondary, Color textMuted) {
    if (_loadingUsers) {
      return Center(
        child: CircularProgressIndicator(color: cs.primary),
      );
    }

    final filteredUsers = _users.where((u) {
      final email = (u['email'] as String? ?? '').toLowerCase();
      return email.contains(_userSearchQuery.toLowerCase());
    }).toList();

    return RefreshIndicator(
      color: cs.primary,
      onRefresh: _loadUsers,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Search box
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: TextField(
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: cs.primary),
                hintText: 'Поиск по email пользователя...',
                hintStyle: TextStyle(fontSize: 12, color: textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (val) => setState(() => _userSearchQuery = val),
            ),
          ),
          const SizedBox(height: 12),

          // Status Counters Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Всего: ${_users.length}   •   🟢 Активных: ${_users.where((u) => u['is_blocked'] != true).length}   •   🔴 Заблокировано: ${_users.where((u) => u['is_blocked'] == true).length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (filteredUsers.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Пользователи не найдены',
                style: TextStyle(fontSize: 13, color: textMuted),
              ),
            ),
          ] else ...[
            for (final user in filteredUsers) _buildUserCard(user, state, cs, textSecondary, textMuted),
          ],
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, AppState state, ColorScheme cs, Color textSecondary, Color textMuted) {
    final semantic = Theme.of(context).extension<SemanticColors>() ?? SemanticColors.light;
    final email = user['email'] as String? ?? 'Неизвестный email';
    final isAdmin = user['is_admin'] as bool? ?? false;
    final isBlocked = user['is_blocked'] as bool? ?? false;
    final createdAt = user['created_at'];
    final blockedAt = user['blocked_at'];
    final isSelf = state.currentUser != null && state.currentUser!.id == user['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isBlocked ? semantic.dangerBorder : cs.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Email, Role and Status Chip
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isBlocked
                      ? semantic.dangerBg
                      : cs.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isBlocked
                        ? semantic.dangerBorder
                        : cs.outlineVariant,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isAdmin ? Icons.shield_rounded : Icons.person_rounded,
                  size: 18,
                  color: isBlocked
                      ? semantic.danger
                      : cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            email,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 4),
                          Text(' (Вы)', style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isAdmin ? cs.primaryContainer : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isAdmin ? 'Администратор' : 'Пользователь',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isAdmin ? cs.primary : textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status Chip: Green "Активен" / Red "Заблокирован"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isBlocked ? semantic.dangerBg : semantic.successBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isBlocked ? semantic.dangerBorder : semantic.successBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isBlocked ? semantic.danger : semantic.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isBlocked ? 'Заблокирован' : 'Активен',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isBlocked ? semantic.dangerText : semantic.successText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 8),

          // Metadata row
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: textMuted),
              const SizedBox(width: 4),
              Text(
                'Регистрация: ${_formatDate(createdAt)}',
                style: TextStyle(fontSize: 10, color: textMuted),
              ),
              if (isBlocked && blockedAt != null) ...[
                const SizedBox(width: 8),
                Text('•', style: TextStyle(fontSize: 10, color: textMuted)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Блок: ${_formatDate(blockedAt)}',
                    style: TextStyle(fontSize: 10, color: semantic.dangerText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Action Switcher: «Заблокировать» / «Разблокировать»
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isSelf)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Текущий аккаунт',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: textMuted),
                  ),
                )
              else if (!isBlocked)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: semantic.dangerText,
                    side: BorderSide(color: semantic.dangerBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _handleToggleBlockUser(user),
                  icon: const Icon(Icons.block_rounded, size: 14),
                  label: const Text(
                    'Заблокировать',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: semantic.successText,
                    side: BorderSide(color: semantic.successBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _handleToggleBlockUser(user),
                  icon: const Icon(Icons.lock_open_rounded, size: 14),
                  label: const Text(
                    'Разблокировать',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrlsTab(ColorScheme cs, Color textSecondary, Color textMuted) {
    return Column(
      children: [
        // Search bar
        Container(
          color: cs.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: TextField(
              controller: _medSearchController,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: cs.primary),
                suffixIcon: _medSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _medSearchController.clear();
                          _loadReferenceMedicines();
                        },
                      )
                    : null,
                hintText: 'Поиск по ГРЛС (название, МНН, штрихкод)...',
                hintStyle: TextStyle(fontSize: 12, color: textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (val) => _loadReferenceMedicines(val.trim()),
            ),
          ),
        ),

        // List
        Expanded(
          child: _loadingMeds
              ? Center(child: CircularProgressIndicator(color: cs.primary))
              : _referenceMedicines.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.medication_liquid_outlined, size: 48, color: textMuted),
                          const SizedBox(height: 10),
                          Text(
                            'Препараты не найдены',
                            style: TextStyle(fontSize: 13, color: textMuted),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              elevation: 0,
                            ),
                            onPressed: _showAddMedicineDialog,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Добавить препарат'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: _referenceMedicines.length,
                      itemBuilder: (context, index) {
                        final med = _referenceMedicines[index];
                        return _buildReferenceMedicineCard(med, cs, textSecondary, textMuted);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildReferenceMedicineCard(ReferenceMedicine med, ColorScheme cs, Color textSecondary, Color textMuted) {
    final semantic = Theme.of(context).extension<SemanticColors>() ?? SemanticColors.light;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                alignment: Alignment.center,
                child: const Text('💊', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.tradeName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'МНН: ${med.inn} • ${med.dosageForm} ${med.dosage}',
                      style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (med.isPrescription)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: semantic.dangerBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: semantic.dangerBorder),
                  ),
                  child: Text(
                    'По рецепту',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: semantic.dangerText),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: semantic.successBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: semantic.successBorder),
                  ),
                  child: Text(
                    'Без рецепта',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: semantic.successText),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 8),
          Row(
            children: [
              if (med.barcode.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.qr_code_rounded, size: 12, color: textMuted),
                      const SizedBox(width: 4),
                      Text(
                        med.barcode,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  '${med.manufacturer} (${med.country})',
                  style: TextStyle(fontSize: 10, color: textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
