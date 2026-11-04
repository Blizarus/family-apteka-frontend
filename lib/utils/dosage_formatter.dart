/// Утилита правильного склонения дозировок лекарственных средств на русском языке.
/// Реализует правила грамматики:
/// - Дробные дозировки (0.5, 1.5): всегда родительный падеж ед.ч. («0.5 таблетки», «1.5 капсулы»).
/// - Числа, оканчивающиеся на 1 (кроме 11): именительный падеж ед.ч. («1 таблетка», «21 капсула»).
/// - Числа, оканчивающиеся на 2, 3, 4 (кроме 12, 13, 14): родительный падеж ед.ч. («2 таблетки», «4 капсулы»).
/// - Остальные (5-9, 0, 11-14): родительный падеж мн.ч. («5 таблеток», «11 капсул»).
class DosageFormatter {
  // Словарь форм: [Им.п. ед.ч., Род.п. ед.ч., Род.п. мн.ч.]
  static const Map<String, List<String>> _forms = {
    'таблетка': ['таблетка', 'таблетки', 'таблеток'],
    'капсула': ['капсула', 'капсулы', 'капсул'],
    'доза': ['доза', 'дозы', 'доз'],
    'капля': ['капля', 'капли', 'капель'],
    'ампула': ['ампула', 'ампулы', 'ампул'],
    'пакетик': ['пакетик', 'пакетика', 'пакетиков'],
    'саше': ['саше', 'саше', 'саше'],
    'мл': ['мл', 'мл', 'мл'],
    'мг': ['мг', 'мг', 'мг'],
    'шт': ['штука', 'штуки', 'штук'],
  };

  /// Нормализует исходную строку формы/единицы измерения
  static String _canonicalForm(String rawForm) {
    final lower = rawForm.trim().toLowerCase().replaceAll('.', '');
    if (lower == 'pill' || lower == 'pills' || lower.startsWith('табл') || lower.startsWith('таб')) return 'таблетка';
    if (lower == 'capsule' || lower == 'capsules' || lower.startsWith('капс')) return 'капсула';
    if (lower == 'spray' || lower == 'sprays' || lower.startsWith('доз')) return 'доза';
    if (lower == 'drop' || lower == 'drops' || lower.startsWith('кап')) return 'капля';
    if (lower == 'ampoule' || lower == 'ampoules' || lower.startsWith('амп')) return 'ампула';
    if (lower.startsWith('пакет')) return 'пакетик';
    if (lower.startsWith('саше')) return 'саше';
    if (lower == 'мл' || lower == 'ml') return 'мл';
    if (lower == 'мг' || lower == 'mg') return 'мг';
    if (lower == 'unit' || lower == 'units' || lower.startsWith('шт')) return 'шт';
    return lower;
  }

  /// Форматирует дозировку со склонением
  /// Пример: format(1, 'таблетка') -> '1 таблетка'
  /// Пример: format(0.5, 'таблетка') -> '0.5 таблетки'
  /// Пример: format(5, 'табл.') -> '5 таблеток'
  static String format(num quantity, String form) {
    final canonical = _canonicalForm(form);
    final formVariants = _forms[canonical];

    // Форматирование числа: целые без '.0', дробные как есть
    final String numberStr = (quantity % 1 == 0)
        ? quantity.toInt().toString()
        : quantity.toString();

    if (formVariants == null) {
      return '$numberStr $form';
    }

    // Правило для дробных чисел: всегда форма родительного падежа единственного числа (индекс 1)
    if (quantity % 1 != 0) {
      return '$numberStr ${formVariants[1]}';
    }

    final int n = quantity.toInt().abs();
    final int rem10 = n % 10;
    final int rem100 = n % 100;

    String word;
    if (rem100 >= 11 && rem100 <= 14) {
      word = formVariants[2];
    } else if (rem10 == 1) {
      word = formVariants[0];
    } else if (rem10 >= 2 && rem10 <= 4) {
      word = formVariants[1];
    } else {
      word = formVariants[2];
    }

    return '$numberStr $word';
  }
}
