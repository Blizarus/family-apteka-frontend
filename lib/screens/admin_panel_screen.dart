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
  late final TabController _tabController;

  // Tab 1: Users State
  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = true;
  String _userSearchQuery = '';

  // Tab 2: GRLS State
  List<ReferenceMedicine> _referenceMedicines = [];
  bool _loadingMeds = true;
  final TextEditingController _medSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
    _loadReferenceMedicines();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _medSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    final state = context.read<AppState>();
    try {
      final list = await state.getAdminUsers();
      if (mounted) {
        setState(() {
          _users = list;
          _loadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingUsers = false);
      }
    }
  }

  Future<void> _loadReferenceMedicines([String query = '']) async {
    setState(() => _loadingMeds = true);
    final state = context.read<AppState>();
    try {
      final list = await state.searchReferenceMedicines(query);
      if (mounted) {
        setState(() {
          _referenceMedicines = list;
          _loadingMeds = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMeds = false);
      }
    }
  }

  Future<void> _handleToggleBlockUser(Map<String, dynamic> user) async {
    final state = context.read<AppState>();
    final userId = user['id'] as int;
    final isBlocked = user['is_blocked'] as bool? ?? false;
    final email = user['email'] as String? ?? 'пользователя';

    // Self-block protection
    if (state.currentUser != null && state.currentUser!.id == userId) {
      ToastHelper.show(
        context,
        message: 'Администратор не может заблокировать свою учетную запись',
        isError: true,
        icon: '⚠️',
      );
      return;
    }

    if (!isBlocked) {
      // Show confirmation dialog before blocking
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Text('⚠️', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Блокировка пользователя',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Вы действительно хотите заблокировать доступ для $email?\n\n'
            'Все активные Sanctum-токены и сессии пользователя будут немедленно аннулированы.',
            style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
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

      await state.toggleBlockUser(userId, true);
      if (mounted) {
        ToastHelper.show(
          context,
          message: 'Пользователь заблокирован, все активные сессии аннулированы',
          icon: '🔒',
          isError: true,
        );
        _loadUsers();
      }
    } else {
      // Unblock
      await state.toggleBlockUser(userId, false);
      if (mounted) {
        ToastHelper.show(
          context,
          message: 'Пользователь $email успешно разблокирован',
          icon: '✓',
        );
        _loadUsers();
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

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Text('💊', style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Добавить препарат в ГРЛС',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      const Text(
                        'Эталонная запись реестра лекарственных средств (ЛР 2)',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 14),

                      // Торговое наименование
                      TextFormField(
                        controller: tradeNameController,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Торговое наименование *',
                          hintText: 'Например, Парацетамол-Ультра',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? 'Обязательное поле' : null,
                      ),
                      const SizedBox(height: 12),

                      // МНН
                      TextFormField(
                        controller: innController,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'МНН (Действующее вещество) *',
                          hintText: 'Например, Парацетамол',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? 'Обязательное поле' : null,
                      ),
                      const SizedBox(height: 12),

                      // Штрихкод
                      TextFormField(
                        controller: barcodeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Штрихкод / EAN-13 *',
                          hintText: '4601234567890',
                          prefixIcon: const Icon(Icons.qr_code_rounded, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Форма выпуска',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                labelText: 'Дозировка *',
                                hintText: '500 мг',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Производитель',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: countryController,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Страна',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Упаковка (ед.)',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('По рецепту', style: TextStyle(fontSize: 12)),
                              value: isPrescription,
                              activeColor: AppColors.primary,
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
                child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
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

                  Navigator.pop(ctx);
                  final state = context.read<AppState>();
                  await state.addReferenceMedicine(payload);

                  if (!mounted) return;
                  ToastHelper.show(
                    context,
                    message: 'Препарат успешно добавлен в справочник ГРЛС',
                    icon: '💊',
                  );
                  _loadReferenceMedicines(_medSearchController.text.trim());
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Панель администратора',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Безопасность ИБ • RBAC • ЛР 2',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6366F1), // Indigo
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryHover),
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
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
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
          _buildUsersTab(state),

          // ==========================================
          // TAB 2: GRLS REFERENCE MEDICINES & ADD FORM
          // ==========================================
          _buildGrlsTab(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          if (_tabController.index == 1) {
            return FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
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

  Widget _buildUsersTab(AppState state) {
    if (_loadingUsers) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final filteredUsers = _users.where((u) {
      final email = (u['email'] as String? ?? '').toLowerCase();
      return email.contains(_userSearchQuery.toLowerCase());
    }).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadUsers,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Search box
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.primaryHover),
                hintText: 'Поиск по email пользователя...',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (val) => setState(() => _userSearchQuery = val),
            ),
          ),
          const SizedBox(height: 12),

          // Status Counters Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF6366F1)),
                const SizedBox(width: 6),
                Text(
                  'Всего: ${_users.length}   •   🟢 Активных: ${_users.where((u) => u['is_blocked'] != true).length}   •   🔴 Заблокировано: ${_users.where((u) => u['is_blocked'] == true).length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (filteredUsers.isEmpty) ...[
            const SizedBox(height: 40),
            const Center(
              child: Text(
                'Пользователи не найдены',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ),
          ] else ...[
            for (final user in filteredUsers) _buildUserCard(user, state),
          ],
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, AppState state) {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: isBlocked ? const Color(0xFFFECDD3) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                      ? const Color(0xFFFFF1F2)
                      : (isAdmin ? const Color(0xFFEEF2FF) : AppColors.primarySurface),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isBlocked
                        ? const Color(0xFFFECDD3)
                        : (isAdmin ? const Color(0xFFC7D2FE) : AppColors.primaryBorderLight),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isAdmin ? Icons.shield_rounded : Icons.person_rounded,
                  size: 18,
                  color: isBlocked
                      ? const Color(0xFFE11D48)
                      : (isAdmin ? const Color(0xFF4F46E5) : AppColors.primaryHover),
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
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 4),
                          const Text(' (Вы)', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isAdmin ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isAdmin ? 'Администратор' : 'Пользователь',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isAdmin ? const Color(0xFF4F46E5) : AppColors.textSecondary,
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
                  color: isBlocked ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isBlocked ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isBlocked ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isBlocked ? 'Заблокирован' : 'Активен',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isBlocked ? const Color(0xFF991B1B) : const Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),

          // Metadata row
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                'Регистрация: ${_formatDate(createdAt)}',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
              if (isBlocked && blockedAt != null) ...[
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Блок: ${_formatDate(blockedAt)}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFFE11D48)),
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Текущий аккаунт',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                  ),
                )
              else if (!isBlocked)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE11D48),
                    side: const BorderSide(color: Color(0xFFFECDD3)),
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
                    foregroundColor: const Color(0xFF16A34A),
                    side: const BorderSide(color: Color(0xFFBBF7D0)),
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

  Widget _buildGrlsTab() {
    return Column(
      children: [
        // Search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _medSearchController,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primaryHover),
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
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (val) => _loadReferenceMedicines(val.trim()),
            ),
          ),
        ),

        // List
        Expanded(
          child: _loadingMeds
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _referenceMedicines.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.medication_liquid_outlined, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 10),
                          const Text(
                            'Препараты не найдены',
                            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
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
                        return _buildReferenceMedicineCard(med);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildReferenceMedicineCard(ReferenceMedicine med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryBorderLight),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'МНН: ${med.inn} • ${med.dosageForm} ${med.dosage}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (med.isPrescription)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: const Text(
                    'По рецепту',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Text(
                    'Без рецепта',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          Row(
            children: [
              if (med.barcode.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_rounded, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        med.barcode,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  '${med.manufacturer} (${med.country})',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
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
