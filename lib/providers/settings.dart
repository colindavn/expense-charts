import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences, saved with shared_preferences.
class SettingsProvider extends ChangeNotifier {
  static const _kBudget = 'monthlyBudget';
  static const _kAlert = 'alertAt80';
  static const _kWeekStart = 'weekStartsOn';
  static const _kTheme = 'themeMode';
  static const _kLastExport = 'lastCsvExport';

  SharedPreferences? _prefs;

  double _monthlyBudget = 1800;
  bool _alertAt80 = true;
  int _weekStartsOn = DateTime.monday;
  ThemeMode _themeMode = ThemeMode.system;
  DateTime? _lastCsvExport;

  double get monthlyBudget => _monthlyBudget;
  bool get alertAt80 => _alertAt80;
  int get weekStartsOn => _weekStartsOn;
  ThemeMode get themeMode => _themeMode;
  DateTime? get lastCsvExport => _lastCsvExport;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      _monthlyBudget = p.getDouble(_kBudget) ?? _monthlyBudget;
      _alertAt80 = p.getBool(_kAlert) ?? _alertAt80;
      _weekStartsOn = p.getInt(_kWeekStart) ?? _weekStartsOn;
      _themeMode = ThemeMode.values[p.getInt(_kTheme) ?? ThemeMode.system.index];
      final last = p.getInt(_kLastExport);
      _lastCsvExport = last == null ? null : DateTime.fromMillisecondsSinceEpoch(last);
    } catch (e) {
      debugPrint('Could not load settings: $e');
    }
    notifyListeners();
  }

  set monthlyBudget(double v) {
    _monthlyBudget = v;
    _prefs?.setDouble(_kBudget, v);
    notifyListeners();
  }

  set alertAt80(bool v) {
    _alertAt80 = v;
    _prefs?.setBool(_kAlert, v);
    notifyListeners();
  }

  set weekStartsOn(int v) {
    _weekStartsOn = v;
    _prefs?.setInt(_kWeekStart, v);
    notifyListeners();
  }

  set themeMode(ThemeMode v) {
    _themeMode = v;
    _prefs?.setInt(_kTheme, v.index);
    notifyListeners();
  }

  set lastCsvExport(DateTime? v) {
    _lastCsvExport = v;
    if (v == null) {
      _prefs?.remove(_kLastExport);
    } else {
      _prefs?.setInt(_kLastExport, v.millisecondsSinceEpoch);
    }
    notifyListeners();
  }
}
