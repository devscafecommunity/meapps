import 'package:flutter_test/flutter_test.dart';
import 'package:mebudget/data/money.dart';

void main() {
  // Narrow no-break space groups thousands; a no-break space precedes "€".
  const g = ' ';
  const eur = ' €';

  group('formatMoney', () {
    test('uses comma decimals and always two of them', () {
      expect(formatMoney(0), '0,00$eur');
      expect(formatMoney(5), '0,05$eur');
      expect(formatMoney(50), '0,50$eur');
      expect(formatMoney(1250), '12,50$eur');
      expect(formatMoney(99999), '999,99$eur');
    });

    test('groups thousands', () {
      expect(formatMoney(123450), '1${g}234,50$eur');
      expect(formatMoney(100000), '1${g}000,00$eur');
      expect(formatMoney(99999999), '999${g}999,99$eur');
      expect(formatMoney(123456789), '1${g}234${g}567,89$eur');
      expect(formatMoney(100000000000), '1${g}000${g}000${g}000,00$eur');
    });

    test('negatives get a leading minus', () {
      expect(formatMoney(-5), '-0,05$eur');
      expect(formatMoney(-123450), '-1${g}234,50$eur');
    });

    test('signed adds "+" to positive amounts only', () {
      expect(formatMoney(1250, signed: true), '+12,50$eur');
      expect(formatMoney(-1250, signed: true), '-12,50$eur');
      expect(formatMoney(0, signed: true), '0,00$eur');
    });
  });

  test('formatMoneyInput writes what parseMoney reads back', () {
    expect(formatMoneyInput(1250), '12,50');
    expect(formatMoneyInput(1205), '12,05');
    expect(formatMoneyInput(1200), '12');
    expect(formatMoneyInput(123456), '1234,56');
    for (final cents in [1, 99, 100, 1250, 123456, 99999999999]) {
      expect(parseMoney(formatMoneyInput(cents)), cents);
    }
  });

  group('parseMoney', () {
    test('accepts whole euros and comma or dot decimals', () {
      expect(parseMoney('12'), 1200);
      expect(parseMoney('12,5'), 1250);
      expect(parseMoney('12,50'), 1250);
      expect(parseMoney('12,05'), 1205);
      expect(parseMoney('12.50'), 1250);
      expect(parseMoney('12.5'), 1250);
      expect(parseMoney('0,01'), 1);
      expect(parseMoney('0.99'), 99);
      expect(parseMoney('007'), 700);
    });

    test('a trailing separator without decimals is whole euros', () {
      expect(parseMoney('12,'), 1200);
      expect(parseMoney('12.'), 1200);
    });

    test('accepts grouped thousands', () {
      expect(parseMoney('1 234,56'), 123456);
      expect(parseMoney('1 234'), 123400);
      expect(parseMoney('12 345 678,9'), 1234567890);
      expect(parseMoney('1 234,56'), 123456);
      expect(parseMoney('1 234,56'), 123456);
      expect(parseMoney('1.234,56'), 123456);
      expect(parseMoney('1.234.567'), 123456700);
      expect(parseMoney('1234,56'), 123456);
    });

    test('ignores surrounding spaces and the euro sign', () {
      expect(parseMoney('  12,50  '), 1250);
      expect(parseMoney('12,50 €'), 1250);
      expect(parseMoney('12,50€'), 1250);
      expect(parseMoney('€ 12'), 1200);
      expect(parseMoney(formatMoney(123450)), 123450);
    });

    test('rejects empty, malformed, zero and negative input', () {
      for (final bad in [
        '',
        '   ',
        '€',
        'abc',
        '12a',
        '1,2,3',
        '12,505',
        ',50',
        '.5',
        '1 23,00',
        '12 34',
        '1.23,45',
        '1.234.56',
        '1,234.56',
        '0',
        '0,00',
        '0.0',
        '-5',
        '-12,50',
        '+5',
        '1e3',
        '1000000000',
      ]) {
        expect(parseMoney(bad), isNull, reason: '"$bad"');
      }
    });

    test('accepts the largest amount', () {
      expect(parseMoney('999 999 999,99'), 99999999999);
    });
  });
}
