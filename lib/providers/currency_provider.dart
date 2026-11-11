import 'package:expenses_charts/models/currency.dart';
import 'package:expenses_charts/utils/database_helper.dart';
import 'package:expenses_charts/utils/format.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available currencies (stored in the database) and the preferred one
/// (stored in preferences). Rates are relative to the preferred currency.
class CurrencyProvider extends ChangeNotifier {
  static const _kPreferred = 'preferredCurrency';

  final DatabaseHelper _db;
  CurrencyProvider([DatabaseHelper? db]) : _db = db ?? DatabaseHelper();

  List<Currency> _currencies = Currency.defaults;
  String _preferred = 'EUR';

  List<Currency> get currencies => _currencies;
  String get preferredCode => _preferred;
  Currency get preferred => byCode(_preferred) ?? Currency.defaults.first;
  Money get money => Money(preferred.symbol);

  Currency? byCode(String? code) {
    for (final c in _currencies) {
      if (c.code == code) return c;
    }
    return null;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _preferred = prefs.getString(_kPreferred) ?? _preferred;
      _currencies = await _db.currencies();
      if (byCode(_preferred) == null && _currencies.isNotEmpty) _preferred = _currencies.first.code;
    } catch (e) {
      debugPrint('Could not load currencies: $e');
    }
    notifyListeners();
  }

  /// Converts [amount] typed in [code] into the preferred currency.
  double toPreferred(double amount, String code) {
    final c = byCode(code);
    if (c == null || c.rate <= 0) return amount;
    return double.parse((amount / c.rate).toStringAsFixed(2));
  }

  Future<void> upsert(Currency c) async {
    await _db.upsertCurrency(c);
    await load();
  }

  /// Returns an error message, or null when removed.
  Future<String?> remove(String code) async {
    if (code == _preferred) return 'The preferred currency cannot be removed.';
    if (await _db.currencyInUse(code)) return 'Some entries use $code, so it cannot be removed.';
    await _db.deleteCurrency(code);
    await load();
    return null;
  }

  /// Makes [code] the preferred currency: every rate is re-based on it and,
  /// if [convertEntries], stored amounts are converted with the current rates.
  Future<void> setPreferred(String code, {required bool convertEntries}) async {
    final next = byCode(code);
    if (next == null || code == _preferred) return;
    final oldCode = _preferred;
    final factor = next.rate; // 1 old = factor new
    for (final c in _currencies) {
      await _db.upsertCurrency(c.copyWith(rate: c.code == code ? 1 : c.rate / factor));
    }
    if (convertEntries) await _db.rebaseValues(oldCode, factor);
    _preferred = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPreferred, code);
    await load();
  }
}
