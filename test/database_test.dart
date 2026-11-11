import 'dart:io';

import 'package:expenses_charts/models/currency.dart';
import 'package:expenses_charts/models/expenses.dart';
import 'package:expenses_charts/providers/currency_provider.dart';
import 'package:expenses_charts/utils/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int noon(int y, int m, int d) => DateTime(y, m, d, 12).millisecondsSinceEpoch;

Expense e(String type, double value, {String category = 'grocery', String label = 'x'}) => Expense(
      millisSinceEpochStart: noon(2026, 11, 10),
      millisSinceEpochEnd: noon(2026, 11, 10),
      type: type,
      category: category,
      label: label,
      value: value,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('expenses_test');
    DatabaseHelper.pathOverride = p.join(tmp.path, 'test.db');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await DatabaseHelper.close();
    DatabaseHelper.pathOverride = null;
    await tmp.delete(recursive: true);
  });

  test('insert, update, delete by id; shares are ignored', () async {
    final db = DatabaseHelper();
    final id = await db.insertExpense(e('expense', 10, label: 'A'));
    await db.insertExpense(e('share', 99, category: 'share'));
    expect((await db.entries()).single.label, 'A');

    await db.updateExpense(id, e('expense', 12, label: 'B'));
    expect((await db.entries()).single.value, 12);

    await db.deleteExpenseById(id);
    expect(await db.entries(), isEmpty);
  });

  test('merge skips duplicates; replace swaps everything', () async {
    final db = DatabaseHelper();
    await db.insertExpense(e('expense', 10, label: 'A'));
    final added = await db.mergeEntries([e('expense', 10, label: 'A'), e('income', 5, category: 'income', label: 'B')]);
    expect(added, 1);
    expect((await db.entries()).length, 2);

    final replaced = await db.replaceEntries([e('expense', 1, label: 'Only')]);
    expect(replaced, 1);
    expect((await db.entries()).single.label, 'Only');
  });

  test('a v2 database is upgraded to v3 without losing rows', () async {
    final path = DatabaseHelper.pathOverride!;
    final old = await openDatabase(path, version: 2, onCreate: (d, v) async {
      await d.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, millisSinceEpochStart INTEGER, '
          'millisSinceEpochEnd INTEGER, type TEXT, category TEXT, label TEXT, value REAL)');
    });
    await old.insert('expenses', {
      'millisSinceEpochStart': noon(2026, 11, 1),
      'millisSinceEpochEnd': noon(2026, 11, 1),
      'type': 'expense',
      'category': 'regular',
      'label': 'Rent',
      'value': 400.0,
    });
    await old.close();

    final db = DatabaseHelper();
    final rows = await db.entries();
    expect(rows.single.label, 'Rent');
    expect(rows.single.currency, isNull);
    expect((await db.currencies()).map((c) => c.code), ['EUR', 'JPY']);
  });

  test('a v1 database is upgraded through v2 and v3', () async {
    final path = DatabaseHelper.pathOverride!;
    final old = await openDatabase(path, version: 1, onCreate: (d, v) async {
      await d.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, millisSinceEpoch INTEGER, '
          'type TEXT, category TEXT, label TEXT, value REAL)');
    });
    await old.insert('expenses', {
      'millisSinceEpoch': noon(2026, 11, 1),
      'type': 'expense',
      'category': 'regular',
      'label': 'Rent',
      'value': 400.0,
    });
    await old.close();

    final rows = await DatabaseHelper().entries();
    expect(rows.length, 1);
    expect(rows.single.millisSinceEpochEnd, rows.single.millisSinceEpochStart);
  });

  group('currencies', () {
    test('converts typed amounts with the stored rate', () async {
      final provider = CurrencyProvider();
      await provider.load();
      expect(provider.preferredCode, 'EUR');
      expect(provider.toPreferred(3500, 'JPY'), 21.34);
      expect(provider.toPreferred(10, 'EUR'), 10);
    });

    test('cannot remove the preferred currency or one in use', () async {
      final provider = CurrencyProvider();
      await provider.load();
      await DatabaseHelper().insertExpense(
        e('expense', 21.34).copyWith(currency: 'JPY', originalValue: 3500),
      );
      expect(await provider.remove('EUR'), isNotNull);
      expect(await provider.remove('JPY'), isNotNull);

      await provider.upsert(const Currency(code: 'USD', symbol: r'$', rate: 1.08));
      expect(await provider.remove('USD'), isNull);
      expect(provider.byCode('USD'), isNull);
    });

    test('switching preferred currency re-bases rates and converts amounts', () async {
      final provider = CurrencyProvider();
      await provider.load();
      await provider.upsert(const Currency(code: 'USD', symbol: r'$', rate: 1.25));
      final db = DatabaseHelper();
      await db.insertExpense(e('expense', 100, label: 'EUR entry'));

      await provider.setPreferred('USD', convertEntries: true);
      expect(provider.preferredCode, 'USD');
      expect(provider.byCode('USD')!.rate, 1);
      expect(provider.byCode('EUR')!.rate, closeTo(0.8, 1e-9));
      expect(provider.byCode('JPY')!.rate, closeTo(131.2, 1e-9));

      final row = (await db.entries()).single;
      expect(row.value, 125);
      expect(row.currency, 'EUR');
      expect(row.originalValue, 100);
      expect((await SharedPreferences.getInstance()).getString('preferredCurrency'), 'USD');
    });
  });
}
