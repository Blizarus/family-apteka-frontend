import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/dosage_formatter.dart';

void main() {
  group('DosageFormatter Russian pluralization tests', () {
    test('1 таблетка (именительный падеж, ед.ч.)', () {
      expect(DosageFormatter.format(1, 'таблетка'), '1 таблетка');
      expect(DosageFormatter.format(21, 'таблетка'), '21 таблетка');
      expect(DosageFormatter.format(101, 'таблетка'), '101 таблетка');
    });

    test('2-4 таблетки (родительный падеж, ед.ч.)', () {
      expect(DosageFormatter.format(2, 'таблетка'), '2 таблетки');
      expect(DosageFormatter.format(3, 'таблетка'), '3 таблетки');
      expect(DosageFormatter.format(4, 'таблетка'), '4 таблетки');
      expect(DosageFormatter.format(22, 'таблетка'), '22 таблетки');
    });

    test('5+ таблеток, 11-14 таблеток (родительный падеж, мн.ч.)', () {
      expect(DosageFormatter.format(5, 'таблетка'), '5 таблеток');
      expect(DosageFormatter.format(6, 'таблетка'), '6 таблеток');
      expect(DosageFormatter.format(10, 'таблетка'), '10 таблеток');
      expect(DosageFormatter.format(11, 'таблетка'), '11 таблеток');
      expect(DosageFormatter.format(12, 'таблетка'), '12 таблеток');
      expect(DosageFormatter.format(14, 'таблетка'), '14 таблеток');
      expect(DosageFormatter.format(20, 'таблетка'), '20 таблеток');
    });

    test('0.5 таблетки (дробные дозировки всегда род. падеж ед.ч.)', () {
      expect(DosageFormatter.format(0.5, 'таблетка'), '0.5 таблетки');
      expect(DosageFormatter.format(1.5, 'таблетка'), '1.5 таблетки');
      expect(DosageFormatter.format(2.5, 'таблетка'), '2.5 таблетки');
    });

    test('Склонение других лекарственных форм (капсулы, капли, мл, дозы)', () {
      expect(DosageFormatter.format(1, 'капсула'), '1 капсула');
      expect(DosageFormatter.format(2, 'капсула'), '2 капсулы');
      expect(DosageFormatter.format(5, 'капсула'), '5 капсул');
      expect(DosageFormatter.format(0.5, 'капсула'), '0.5 капсулы');

      expect(DosageFormatter.format(1, 'капля'), '1 капля');
      expect(DosageFormatter.format(3, 'капля'), '3 капли');
      expect(DosageFormatter.format(10, 'капля'), '10 капель');

      expect(DosageFormatter.format(1, 'мл'), '1 мл');
      expect(DosageFormatter.format(5, 'мл'), '5 мл');
      expect(DosageFormatter.format(2.5, 'мл'), '2.5 мл');

      expect(DosageFormatter.format(1, 'доза'), '1 доза');
      expect(DosageFormatter.format(2, 'доза'), '2 дозы');
      expect(DosageFormatter.format(5, 'доза'), '5 доз');
    });

    test('Автоматическое распознавание сокращений (табл, таб, капс)', () {
      expect(DosageFormatter.format(1, 'табл.'), '1 таблетка');
      expect(DosageFormatter.format(2, 'табл'), '2 таблетки');
      expect(DosageFormatter.format(5, 'табл'), '5 таблеток');
      expect(DosageFormatter.format(0.5, 'табл'), '0.5 таблетки');
      expect(DosageFormatter.format(1, 'капс.'), '1 капсула');
      expect(DosageFormatter.format(3, 'капс'), '3 капсулы');
      expect(DosageFormatter.format(6, 'капс'), '6 капсул');
    });
  });
}
