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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

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
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('📋', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              'Список для отправки',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Список скопирован в буфер обмена! Вы можете отправить его родственникам в Telegram, WhatsApp или SMS:',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: SingleChildScrollView(
                child: Text(
                  shareText,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Закрыть',
              style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AddShoppingItemDialog(state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);

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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Список покупок в аптеку',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            Text(
              activeItems.isEmpty
                  ? 'Все препараты в наличии'
                  : '${activeItems.length} поз. требуется купить',
              style: TextStyle(
                fontSize: 11,
                color: textMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, size: 20, color: cs.primary),
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
                _buildInfoBanner(context),
                const SizedBox(height: 12),

                // Grouped Active Items
                if (activeItems.isNotEmpty)
                  ...grouped.entries.map((entry) {
                    return _buildPatientGroup(context, state, entry.key, entry.value);
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
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.05),
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
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
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

  Widget _buildInfoBanner(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.swipe_outlined, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Свайп вправо — «Куплено!» (добавит в аптечку).\nСвайп влево — удалить позицию.',
              style: TextStyle(
                fontSize: 11,
                color: cs.onPrimaryContainer,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientGroup(
    BuildContext context,
    AppState state,
    String patientName,
    List<ShoppingItem> items,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: cs.outlineVariant),
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
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person_pin_outlined,
                    size: 14,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    patientName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length} поз.',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),

          // Items inside group
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isLast = idx == items.length - 1;

            return Column(
              children: [
                _buildDismissibleItem(context, state, item, idx),
                if (!isLast) Divider(height: 1, indent: 44, color: cs.outlineVariant),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDismissibleItem(
    BuildContext context,
    AppState state,
    ShoppingItem item,
    int index,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

    return Dismissible(
      key: Key('shopping_item_${item.id}_${item.name}'),
      direction: DismissDirection.horizontal,
      background: Container(
        color: semantic.successBg,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(Icons.shopping_cart_checkout_rounded, color: semantic.success, size: 22),
            const SizedBox(width: 8),
            Text(
              'Куплено!',
              style: TextStyle(
                color: semantic.successText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: semantic.dangerBg,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Удалить',
              style: TextStyle(
                color: semantic.dangerText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: semantic.danger, size: 22),
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
              backgroundColor: cs.inverseSurface,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Text('✅ ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      '«${item.name}» куплен и добавлен в аптечку!',
                      style: TextStyle(fontSize: 12, color: cs.onInverseSurface),
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'Отмена',
                textColor: cs.primary,
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
              backgroundColor: cs.inverseSurface,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(
                '«${item.name}» удален из списка',
                style: TextStyle(fontSize: 12, color: cs.onInverseSurface),
              ),
              action: SnackBarAction(
                label: 'Отмена',
                textColor: cs.primary,
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
                backgroundColor: cs.inverseSurface,
                duration: const Duration(seconds: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                content: Text('«${item.name}» перемещен в купленные', style: TextStyle(color: cs.onInverseSurface)),
                action: SnackBarAction(
                  label: 'Отмена',
                  textColor: cs.primary,
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
              border: Border.all(color: cs.outline, width: 1.5),
            ),
            child: const Icon(Icons.circle_outlined, size: 16, color: Colors.transparent),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text(
                '${item.count} уп.',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: cs.onPrimaryContainer,
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
                style: TextStyle(fontSize: 11, color: textSecondary),
              ),
            ],
            if (item.sourceDescription?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 11, color: textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.sourceDescription!,
                      style: TextStyle(
                        fontSize: 10,
                        color: textMuted,
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: cs.outlineVariant),
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
                      color: semantic.successBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.check, size: 14, color: semantic.success),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Куплено (${purchasedItems.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    _isPurchasedExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_isPurchasedExpanded) ...[
            Divider(height: 1, color: cs.outlineVariant),
            ...purchasedItems.map((item) {
              return ListTile(
                dense: true,
                leading: Icon(
                  Icons.check_circle,
                  color: semantic.success,
                  size: 20,
                ),
                title: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 12,
                    decoration: TextDecoration.lineThrough,
                    color: textMuted,
                  ),
                ),
                subtitle: item.dosage.isNotEmpty
                    ? Text(
                        item.dosage,
                        style: TextStyle(fontSize: 10, color: textMuted),
                      )
                    : null,
                trailing: TextButton(
                  onPressed: () => state.unpurchaseShoppingItem(item),
                  child: Text(
                    'Вернуть',
                    style: TextStyle(fontSize: 11, color: cs.primary),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: semantic.success, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Все актуальные лекарства куплены! Новые появятся при назначениях врачей или нехватке таблеток на курс.',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppState state) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

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
                color: cs.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: cs.outlineVariant, width: 2),
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 38,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Список покупок пуст',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Все необходимые медикаменты есть в аптечке.\nКрасные бейджи препаратов в разделе «Заметки» и напоминания о курсах помогут сформировать список покупок.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
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
                side: BorderSide(color: cs.outlineVariant),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showAddItemDialog(context, state),
              icon: Icon(Icons.add, size: 16, color: cs.onSurface),
              label: Text(
                '+ Добавить вручную',
                style: TextStyle(fontSize: 12, color: cs.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddShoppingItemDialog extends StatefulWidget {
  final AppState state;

  const _AddShoppingItemDialog({required this.state});

  @override
  State<_AddShoppingItemDialog> createState() => _AddShoppingItemDialogState();
}

class _AddShoppingItemDialogState extends State<_AddShoppingItemDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  int _count = 1;

  late final List<String> _profileNames;
  late String _selectedPatient;
  String _selectedSource = 'Пополнение аптечки';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dosageController = TextEditingController();

    _profileNames = <String>['Общие'];
    for (final p in widget.state.profiles) {
      _profileNames.add(p.name);
    }
    _selectedPatient = _profileNames.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('🛒', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      'Добавить в список покупок',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Medicine Name
            Text(
              'НАИМЕНОВАНИЕ ПРЕПАРАТА',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Например: Нурофен 400мг',
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
            ),
            const SizedBox(height: 12),

            // Dosage & Quantity
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ДОЗИРОВКА / ФОРМА',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _dosageController,
                        decoration: InputDecoration(
                          hintText: 'Таблетки / Спрей',
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outlineVariant),
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
                    Text(
                      'КОЛ-ВО',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16),
                            onPressed: _count > 1
                                ? () => setState(() => _count--)
                                : null,
                          ),
                          Text(
                            '$_count',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: cs.onSurface,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16),
                            onPressed: () => setState(() => _count++),
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
            Text(
              'ДЛЯ КОГО:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _profileNames.map((name) {
                final isSel = _selectedPatient == name;
                return ChoiceChip(
                  label: Text(name),
                  selected: isSel,
                  onSelected: (val) {
                    if (val) setState(() => _selectedPatient = name);
                  },
                  selectedColor: cs.primaryContainer,
                  backgroundColor: cs.surfaceContainerHighest,
                  side: BorderSide(
                    color: isSel ? cs.primary : cs.outlineVariant,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? cs.onPrimaryContainer : textSecondary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Source of need
            Text(
              'ПРИЧИНА ДОБАВЛЕНИЯ:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: textMuted,
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
                final isSel = _selectedSource == src;
                return ChoiceChip(
                  label: Text(src),
                  selected: isSel,
                  onSelected: (val) {
                    if (val) setState(() => _selectedSource = src);
                  },
                  selectedColor: cs.primaryContainer,
                  backgroundColor: cs.surfaceContainerHighest,
                  side: BorderSide(
                    color: isSel ? cs.primary : cs.outlineVariant,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 10,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? cs.onPrimaryContainer : textSecondary,
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
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  final medName = _nameController.text.trim();
                  if (medName.isEmpty) return;

                  widget.state.addToShoppingList(
                    medName,
                    quantity: _count,
                    dosage: _dosageController.text.trim(),
                    patientName: _selectedPatient == 'Общие'
                        ? 'Общие запасы'
                        : 'Для $_selectedPatient',
                    sourceDescription: _selectedSource,
                  );

                  Navigator.pop(context);
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
  }
}
