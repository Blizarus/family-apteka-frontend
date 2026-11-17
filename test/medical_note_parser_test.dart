import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/medical_note.dart';
import 'package:frontend/models/medicine.dart';

void main() {
  group('DEF-50: Medical Note Prescriptions Dynamic Parser Tests', () {
    final List<Medicine> inventory = [
      const Medicine(
        id: 1,
        boxId: 1,
        name: 'Парацетамол 500 мг',
        substance: 'парацетамол',
        form: 'Таблетки',
        remaining: 20,
        total: 20,
        expiry: '2026-12-31',
        status: 'active',
      ),
      const Medicine(
        id: 2,
        boxId: 1,
        name: 'Дротаверин Форте',
        substance: 'дротаверин',
        form: 'Таблетки',
        remaining: 10,
        total: 20,
        expiry: '2027-01-01',
        status: 'active',
      ),
    ];

    test('Parses built-in keywords and matches against inventory', () {
      const text = 'Принимать Парацетамол при повышении температуры.';
      final items = MedicalNote.parseAndMatch(text, inventory);

      expect(items.length, 1);
      expect(items.first.name, 'Парацетамол 500 мг');
      expect(items.first.status, MedicineStockStatus.inStock);
    });

    test('Parses external catalog items (GRLS / dynamic reference) not in hardcoded list', () {
      const text = 'Назначен курс: Дротаверин по 1 таблетке и Кларитромицин 500 мг.';
      final externalCatalog = ['Дротаверин', 'Кларитромицин'];

      final items = MedicalNote.parseAndMatch(
        text,
        inventory,
        externalCatalog: externalCatalog,
      );

      expect(items.length, 2);

      final drotaverin = items.firstWhere((i) => i.name.contains('Дротаверин'));
      expect(drotaverin.status, MedicineStockStatus.inStock);

      final clarithro = items.firstWhere((i) => i.name.contains('Кларитромицин'));
      expect(clarithro.status, MedicineStockStatus.missing);
      expect(clarithro.locationInfo, contains('найдено в ГРЛС'));
    });
  });
}
