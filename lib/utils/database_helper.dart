import 'dart:io';

import 'package:expenses_charts/models/currency.dart';
import 'package:expenses_charts/models/expenses.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Single access point to the SQLite file.
class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  /// Tests can point this at `inMemoryDatabasePath` before first use.
  static String? pathOverride;

  static const int version = 3;
  static const String fileName = 'expense_database.db';

  factory DatabaseHelper() => _instance ??= DatabaseHelper._internal();
  DatabaseHelper._internal();

  Future<Database> _getDatabase() async {
    _database ??= await _open();
    return _database!;
  }

  /// Closes the connection (used before replacing the file, and by tests).
  static Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  static Future<String> databasePath() async {
    if (pathOverride != null) return pathOverride!;
    final Directory dir;
    if (Platform.isLinux) {
      dir = File(Platform.script.toFilePath()).parent;
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    return join(dir.path, fileName);
  }

  Future<Database> _open() async {
    return openDatabase(
      await databasePath(),
      version: version,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            millisSinceEpochStart INTEGER,
            millisSinceEpochEnd INTEGER,
            type TEXT,
            category TEXT,
            label TEXT,
            value REAL,
            currency TEXT,
            originalValue REAL
          )
        ''');
        await _createCurrencies(db);
      },
      onUpgrade: upgrade,
    );
  }

  static Future<void> _createCurrencies(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS currencies(
        code TEXT PRIMARY KEY,
        symbol TEXT NOT NULL,
        rate REAL NOT NULL
      )
    ''');
    for (final c in Currency.defaults) {
      await db.insert('currencies', c.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// v1 → v2: rename the date column and add an end date.
  /// v2 → v3: currencies table, per-entry currency and original amount.
  static Future<void> upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE expenses RENAME COLUMN millisSinceEpoch TO millisSinceEpochStart');
      await db.execute('ALTER TABLE expenses ADD COLUMN millisSinceEpochEnd INTEGER');
      await db.execute('UPDATE expenses SET millisSinceEpochEnd = millisSinceEpochStart');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE expenses ADD COLUMN currency TEXT');
      await db.execute('ALTER TABLE expenses ADD COLUMN originalValue REAL');
      await _createCurrencies(db);
    }
  }

  // ---------- Entries ----------

  /// Every expense and income. Legacy "share" rows are ignored.
  Future<List<Expense>> entries() async {
    final db = await _getDatabase();
    final maps = await db.query(
      'expenses',
      where: "type IN ('expense', 'income')",
      orderBy: 'millisSinceEpochStart DESC, id DESC',
    );
    return maps.map(Expense.fromMap).toList();
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await _getDatabase();
    return db.insert('expenses', expense.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateExpense(int id, Expense expense) async {
    final db = await _getDatabase();
    await db.update('expenses', expense.toMap(), where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExpenseById(int id) async {
    final db = await _getDatabase();
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  /// Converts every stored value when the preferred currency changes from
  /// [oldCode]. Entries without a currency were in [oldCode]: that is recorded
  /// first so the typed amount is not lost.
  Future<void> rebaseValues(String oldCode, double factor) async {
    final db = await _getDatabase();
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE expenses SET currency = ?, originalValue = value WHERE currency IS NULL',
        [oldCode],
      );
      await txn.rawUpdate('UPDATE expenses SET value = ROUND(value * ?, 2)', [factor]);
    });
  }

  Future<bool> existsInExistingDatabase(Map<String, dynamic> row) async {
    final e = Expense.fromMap(row);
    final db = await _getDatabase();
    final count = Sqflite.firstIntValue(await db.rawQuery(
      '''
      SELECT COUNT(*) FROM expenses
      WHERE millisSinceEpochStart = ? AND millisSinceEpochEnd = ?
        AND type = ? AND category = ? AND label = ? AND value = ?
      ''',
      [e.millisSinceEpochStart, e.millisSinceEpochEnd, e.type, e.category, e.label, e.value],
    ));
    return (count ?? 0) > 0;
  }

  /// Inserts the rows not already present. Returns how many were added.
  Future<int> mergeEntries(List<Expense> rows) async {
    var added = 0;
    for (final row in rows) {
      if (row.type != 'expense' && row.type != 'income') continue;
      if (await existsInExistingDatabase(row.toMap())) continue;
      await insertExpense(Expense.fromMap({...row.toMap(), 'id': null}));
      added++;
    }
    return added;
  }

  /// Deletes every entry and inserts [rows] instead.
  Future<int> replaceEntries(List<Expense> rows) async {
    final db = await _getDatabase();
    var added = 0;
    await db.transaction((txn) async {
      await txn.delete('expenses');
      for (final row in rows) {
        if (row.type != 'expense' && row.type != 'income') continue;
        final map = row.toMap();
        await txn.insert('expenses', map);
        added++;
      }
    });
    return added;
  }

  // ---------- Currencies ----------

  Future<List<Currency>> currencies() async {
    final db = await _getDatabase();
    final maps = await db.query('currencies', orderBy: 'code');
    return maps.map(Currency.fromMap).toList();
  }

  Future<void> upsertCurrency(Currency c) async {
    final db = await _getDatabase();
    await db.insert('currencies', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCurrency(String code) async {
    final db = await _getDatabase();
    await db.delete('currencies', where: 'code = ?', whereArgs: [code]);
  }

  Future<bool> currencyInUse(String code) async {
    final db = await _getDatabase();
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM expenses WHERE currency = ?', [code]),
    );
    return (count ?? 0) > 0;
  }
}
