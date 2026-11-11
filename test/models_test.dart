import 'package:expenses_charts/models/currency.dart';
import 'package:expenses_charts/models/expenses.dart';
import 'package:flutter_test/flutter_test.dart';

int noon(int y, int m, int d) => DateTime(y, m, d, 12).millisecondsSinceEpoch;

void main() {
  test('Expense maps to and from a database row', () {
    final e = Expense(
      id: 3,
      millisSinceEpochStart: noon(2026, 11, 7),
      millisSinceEpochEnd: noon(2026, 11, 9),
      type: 'expense',
      category: 'trip',
      label: 'Hotel — Lyon',
      value: 210,
      currency: 'JPY',
      originalValue: 34440,
    );
    final map = e.toMap();
    expect(map.containsKey('id'), isFalse);
    expect(map['currency'], 'JPY');
    final back = Expense.fromMap({...map, 'id': 3});
    expect(back.id, 3);
    expect(back.label, 'Hotel — Lyon');
    expect(back.value, 210);
    expect(back.originalValue, 34440);
  });

  test('fromMap accepts strings and a missing end date', () {
    final e = Expense.fromMap({
      'millisSinceEpochStart': '${noon(2026, 11, 7)}',
      'type': 'income',
      'category': 'income',
      'label': 'Salary',
      'value': '2450,5',
    });
    expect(e.millisSinceEpochEnd, e.millisSinceEpochStart);
    expect(e.value, 2450.5);
    expect(e.currency, isNull);
  });

  test('Period entries count calendar days', () {
    final e = Expense(
      millisSinceEpochStart: noon(2026, 11, 7),
      millisSinceEpochEnd: noon(2026, 11, 9),
      type: 'expense',
      category: 'trip',
      label: 'Hotel',
      value: 210,
    );
    expect(e.days, 3);
    expect(e.isPeriod, isTrue);
    expect(e.perDay, 70);
  });

  test('Period across a daylight-saving change still counts whole days', () {
    final e = Expense(
      millisSinceEpochStart: noon(2026, 10, 24),
      millisSinceEpochEnd: noon(2026, 10, 26),
      type: 'expense',
      category: 'trip',
      label: 'Weekend',
      value: 90,
    );
    expect(e.days, 3);
  });

  test('Default currencies keep the old EUR/JPY behaviour', () {
    expect(Currency.defaults.map((c) => c.code), ['EUR', 'JPY']);
    expect(Currency.defaults.last.rate, 164);
  });
}
