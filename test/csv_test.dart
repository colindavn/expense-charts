import 'package:expenses_charts/models/expenses.dart';
import 'package:expenses_charts/services/data_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

int noon(int y, int m, int d) => DateTime(y, m, d, 12).millisecondsSinceEpoch;

void main() {
  final entries = [
    Expense(millisSinceEpochStart: noon(2026, 11, 9), millisSinceEpochEnd: noon(2026, 11, 9), type: 'expense', category: 'restaurant', label: 'Dinner, "out"', value: 42.8),
    Expense(millisSinceEpochStart: noon(2026, 11, 6), millisSinceEpochEnd: noon(2026, 11, 6), type: 'income', category: 'income', label: 'Salary', value: 2450),
    Expense(millisSinceEpochStart: noon(2026, 11, 2), millisSinceEpochEnd: noon(2026, 11, 2), type: 'expense', category: 'grocery', label: 'Groceries', value: 54),
  ];

  test('export uses the processing script columns', () {
    final csv = CsvCodec.encode(entries);
    final lines = csv.trim().split('\n');
    expect(lines.first, 'Date,Intitulé,Montant,Type,Revenu/Dépense');
    expect(lines[1], '11/09/2026,"Dinner, ""out""",42.8,Restaurant,-1');
    expect(lines[2], '11/06/2026,Salary,2450.0,,1');
    expect(lines[3], '11/02/2026,Groceries,54.0,Course,-1');
  });

  test('export then import gives the same entries', () {
    final back = CsvCodec.decode(CsvCodec.encode(entries));
    expect(back.length, 3);
    for (var i = 0; i < 3; i++) {
      expect(back[i].millisSinceEpochStart, entries[i].millisSinceEpochStart);
      expect(back[i].type, entries[i].type);
      expect(back[i].category, entries[i].category);
      expect(back[i].label, entries[i].label);
      expect(back[i].value, entries[i].value);
    }
  });

  test('import reads Windows line endings and French categories', () {
    const csv = 'Date,Intitulé,Montant,Type,Revenu/Dépense\r\n11/08/2026,Drinks,16.5,Alcool,-1\r\n11/08/2026,Cinéma,23,Plaisir,-1\r\n';
    final rows = CsvCodec.decode(csv);
    expect(rows.map((e) => e.category), ['alcohol', 'leisure']);
    expect(rows.last.label, 'Cinéma');
  });

  test('import still accepts the old raw-column format and skips shares', () {
    final csv = 'id,millisSinceEpochStart,millisSinceEpochEnd,type,category,label,value\n'
        '1,${noon(2026, 11, 7)},${noon(2026, 11, 9)},expense,trip,Hotel,210.0\n'
        '2,${noon(2026, 11, 7)},${noon(2026, 11, 7)},share,share,ACME,100\n';
    final rows = CsvCodec.decode(csv);
    expect(rows.single.days, 3);
    expect(rows.single.value, 210);
  });

  test('unknown columns are rejected', () {
    expect(() => CsvCodec.decode('a,b\n1,2\n'), throwsFormatException);
  });
}
