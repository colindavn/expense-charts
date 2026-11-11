import 'package:expenses_charts/models/expenses.dart';
import 'package:expenses_charts/utils/database_helper.dart';
import 'package:flutter/foundation.dart';

/// Every entry, kept in memory. Screens compute their views from [entries].
class ExpenseStore extends ChangeNotifier {
  final DatabaseHelper _db;
  ExpenseStore([DatabaseHelper? db]) : _db = db ?? DatabaseHelper();

  List<Expense> _entries = const [];
  bool _loaded = false;

  /// Newest first.
  List<Expense> get entries => _entries;
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      _entries = await _db.entries();
    } catch (e) {
      debugPrint('Could not load entries: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save(Expense e) async {
    if (e.id == null) {
      await _db.insertExpense(e);
    } else {
      await _db.updateExpense(e.id!, e);
    }
    await load();
  }

  Future<void> delete(Expense e) async {
    if (e.id == null) return;
    await _db.deleteExpenseById(e.id!);
    await load();
  }
}
