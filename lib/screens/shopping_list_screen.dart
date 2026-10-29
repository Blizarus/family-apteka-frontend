import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/shopping_item.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/toast_helper.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  bool _isPurchasedExpanded = false;

  void _shareShoppingList(BuildContext context, AppState state) {
    final activeItems = state.shoppingItems;
    final purchasedItems = state.purchasedItems;

    if (activeItems.isEmpty && purchasedItems.isEmpty) {
      ToastHelper.show(
        context,
        message: 'Список покупок пуст — нечего отправлять',
        icon: 'ℹ️',
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('🛒 Список покупок в аптеку («Семейная Аптечка»)');
    buffer.writeln('─' * 32);

    // Group active items by patient
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in activeItems) {
      final key = item.patientName?.isNotEmpty == true
          ? item.patientName!
          : 'Общие запасы';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    grouped.forEach((patient, items) {
      buffer.writeln('\n[$patient]:');
      for (final item in items) {
        final dosagePart =
            item.dosage.isNotEmpty ? ' ${item.dosage}' : '';
        final countPart = item.count > 1 ? ' (${item.count} уп./шт.)' : '';
        final sourcePart = item.sourceDescription?.isNotEmpty == true
            ? ' — ${item.sourceDescription}'
            : '';
        buffer.writeln('  [ ] ${item.name}$dosagePart$countPart$sourcePart');
      }
    });

    if (purchasedItems.isNotEmpty) {
      buffer.writeln('\nУже куплено:');
      for (final item in purchasedItems) {
        buffer.writeln('  [✓] ${item.name}');
      }
    }

    buffer.writeln('\nСформировано в приложении «Семейная Аптечка»');

    final shareText = buffer.toString();

    Clipboard.setData(ClipboardData(text: shareText));

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('📋', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Список для отправки',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Список скопирован в буфер обмена! Вы можете отправить его родственникам в Telegram, WhatsApp или SMS:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                child: Text(
                  shareText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Закрыть',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryHover),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ToastHelper.show(
                context,
                message: 'Готово к отправке в Telegram / SMS!',
                icon: '🚀',
              );
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    int count = 1;

    final profileNames = <String>['Общие'];
    for (final p in state.profiles) {
      profileNames.add(p.name);
    }
    String selectedPatient = profileNames.first;
    String selectedSource = 'Пополнение аптечки';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              margin: EdgeInsets.only(bottom: bottomPadding),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderDarker,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Text('🛒', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 8),
                          Text(
                            'Добавить в список покупок',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Medicine Name
                  const Text(
                    'НАИМЕНОВАНИЕ ПРЕПАРАТА',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Например: Нурофен 400мг',
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
                  ),
                  const SizedBox(height: 12),

                  // Dosage & Quantity
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ДОЗИРОВКА / ФОРМА',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: dosageCtrl,
                              decoration: InputDecoration(
                                hintText: 'Таблетки / Спрей',
                                filled: true,
                                fillColor: AppColors.surfaceSubtle,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'КОЛ-ВО',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 16),
                                  onPressed: count > 1
                                      ? () => setSheetState(() => count--)
                                      : null,
                                ),
                                Text(
                                  '$count',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 16),
                                  onPressed: () => setSheetState(() => count++),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // For who (Patient)
                  const Text(
                    'ДЛЯ КОГО:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: profileNames.map((name) {
                      final isSel = selectedPatient == name;
                      return ChoiceChip(
                        label: Text(name),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) setSheetState(() => selectedPatient = name);
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
                  const SizedBox(height: 12),

                  // Source of need
                  const Text(
                    'ПРИЧИНА ДОБАВЛЕНИЯ:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      'Пополнение аптечки',
                      'Из рецепта врача',
                      'Не хватает на курс',
                    ].map((src) {
                      final isSel = selectedSource == src;
                      return ChoiceChip(
                        label: Text(src),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) setSheetState(() => selectedSource = src);
                        },
                        selectedColor: AppColors.primarySurface,
                        backgroundColor: AppColors.surfaceSubtle,
                        side: BorderSide(
                          color: isSel ? AppColors.primary : AppColors.border,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 10,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? AppColors.primaryHover : AppColors.textSecondary,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

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
                      onPressed: () {
                        final medName = nameCtrl.text.trim();
                        if (medName.isEmpty) return;

                        state.addToShoppingList(
                          medName,
                          quantity: count,
                          dosage: dosageCtrl.text.trim(),
                          patientName: selectedPatient == 'Общие'
                              ? 'Общие запасы'
                              : 'Для $selectedPatient',
                          sourceDescription: selectedSource,
                        );

                        Navigator.pop(sheetContext);
                        ToastHelper.show(
                          context,
                          message: '«$medName» добавлен в список покупок',
                          icon: '🛒',
                        );
                      },
                      child: const Text(
                        'Сохранить в список',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final activeItems = state.shoppingItems;
    final purchasedItems = state.purchasedItems;

    // Grouping active items by patient
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in activeItems) {
      final key = (item.patientName?.isNotEmpty == true)
          ? item.patientName!
          : 'Общие запасы';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Список покупок в аптеку',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              activeItems.isEmpty
                  ? 'Все препараты в наличии'
                  : '${activeItems.length} поз. требуется купить',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20, color: AppColors.primaryHover),
            tooltip: 'Поделиться списком',
            onPressed: () => _shareShoppingList(context, state),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: activeItems.isEmpty && purchasedItems.isEmpty
          ? _buildEmptyState(context, state)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              children: [
                // Info Banner
                _buildInfoBanner(),
                const SizedBox(height: 12),

                // Grouped Active Items
                if (activeItems.isNotEmpty)
                  ...grouped.entries.map((entry) {
                    return _buildPatientGroup(state, entry.key, entry.value);
                  })
                else
                  _buildNoActiveItemsCard(context, state),

                const SizedBox(height: 16),

                // Purchased Accordion Block
                if (purchasedItems.isNotEmpty)
                  _buildPurchasedSection(context, state, purchasedItems),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _showAddItemDialog(context, state),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Добавить в список',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBorderLight),
      ),
      child: const Row(
        children: [
          Icon(Icons.swipe_outlined, size: 18, color: AppColors.primaryHover),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Свайп вправо — «Куплено!» (добавит в аптечку).\nСвайп влево — удалить позицию.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primaryDeep,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientGroup(
    AppState state,
    String patientName,
    List<ShoppingItem> items,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_pin_outlined,
                    size: 14,
                    color: AppColors.primaryHover,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length} поз.',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Items inside group
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isLast = idx == items.length - 1;

            return Column(
              children: [
                _buildDismissibleItem(state, item, idx),
                if (!isLast) const Divider(height: 1, indent: 44, color: AppColors.border),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDismissibleItem(
    AppState state,
    ShoppingItem item,
    int index,
  ) {
    return Dismissible(
      key: Key('shopping_item_${item.id}_${item.name}'),
      direction: DismissDirection.horizontal,
      background: Container(
        color: AppColors.statusOkBg,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          children: [
            Icon(Icons.shopping_cart_checkout_rounded, color: AppColors.statusOkDot, size: 22),
            SizedBox(width: 8),
            Text(
              'Куплено!',
              style: TextStyle(
                color: AppColors.statusOkText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: AppColors.statusExpiredBg,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Удалить',
              style: TextStyle(
                color: AppColors.statusExpiredText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 22),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Purchase
          HapticFeedback.mediumImpact();
          final messenger = ScaffoldMessenger.of(context);
          final purchased = await state.purchaseShoppingItem(item.name, count: item.count);

          messenger.clearSnackBars();
          messenger.showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.textPrimary,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Text('✅ ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      '«${item.name}» куплен и добавлен в аптечку!',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'Отмена',
                textColor: const Color(0xFF2DD4BF),
                onPressed: () {
                  if (purchased != null) {
                    state.unpurchaseShoppingItem(purchased);
                  }
                },
              ),
            ),
          );
          return true;
        } else {
          // Swipe Left: Remove
          HapticFeedback.mediumImpact();
          final messenger = ScaffoldMessenger.of(context);
          final removed = state.removeFromShoppingList(item.id);

          messenger.clearSnackBars();
          messenger.showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.textPrimary,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(
                '«${item.name}» удален из списка',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
              action: SnackBarAction(
                label: 'Отмена',
                textColor: const Color(0xFF2DD4BF),
                onPressed: () {
                  if (removed != null) {
                    state.restoreShoppingItem(removed, index);
                  }
                },
              ),
            ),
          );
          return true;
        }
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            HapticFeedback.lightImpact();
            final messenger = ScaffoldMessenger.of(context);
            final purchased = await state.purchaseShoppingItem(item.name, count: item.count);
            messenger.clearSnackBars();
            messenger.showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.textPrimary,
                duration: const Duration(seconds: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                content: Text('«${item.name}» перемещен в купленные'),
                action: SnackBarAction(
                  label: 'Отмена',
                  textColor: const Color(0xFF2DD4BF),
                  onPressed: () {
                    if (purchased != null) {
                      state.unpurchaseShoppingItem(purchased);
                    }
                  },
                ),
              ),
            );
          },
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderDarker, width: 1.5),
            ),
            child: const Icon(Icons.circle_outlined, size: 16, color: Colors.transparent),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primaryBorderLight),
              ),
              child: Text(
                '${item.count} уп.',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryHover,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.dosage.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.dosage,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
            if (item.sourceDescription?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.sourceDescription!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPurchasedSection(
    BuildContext context,
    AppState state,
    List<ShoppingItem> purchasedItems,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            onTap: () {
              setState(() => _isPurchasedExpanded = !_isPurchasedExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.statusOkBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.check, size: 14, color: AppColors.statusOkDot),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Куплено (${purchasedItems.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _isPurchasedExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_isPurchasedExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            ...purchasedItems.map((item) {
              return ListTile(
                dense: true,
                leading: const Icon(
                  Icons.check_circle,
                  color: AppColors.statusOkDot,
                  size: 20,
                ),
                title: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 12,
                    decoration: TextDecoration.lineThrough,
                    color: AppColors.textMuted,
                  ),
                ),
                subtitle: item.dosage.isNotEmpty
                    ? Text(
                        item.dosage,
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                      )
                    : null,
                trailing: TextButton(
                  onPressed: () => state.unpurchaseShoppingItem(item),
                  child: const Text(
                    'Вернуть',
                    style: TextStyle(fontSize: 11, color: AppColors.primaryHover),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildNoActiveItemsCard(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.statusOkDot, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Все актуальные лекарства куплены! Новые появятся при назначениях врачей или нехватке таблеток на курс.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppState state) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryBorderLight, width: 2),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Список покупок пуст',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Все необходимые медикаменты есть в аптечке.\nКрасные бейджи препаратов в разделе «Заметки» и напоминания о курсах помогут сформировать список покупок.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                state.setTab(2); // Переход на таб "Заметки"
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text(
                'Перейти к назначениям врачей',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showAddItemDialog(context, state),
              icon: const Icon(Icons.add, size: 16, color: AppColors.textPrimary),
              label: const Text(
                '+ Добавить вручную',
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
