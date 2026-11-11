import 'package:expenses_charts/utils/dates.dart';

/// One entry (expense or income). A period entry covers several days,
/// from [millisSinceEpochStart] to [millisSinceEpochEnd] (both inclusive).
///
/// [value] is always stored in the preferred currency. When the entry was
/// typed in another currency, [currency] and [originalValue] keep what the
/// user typed.
class Expense {
  final int? id;
  final int millisSinceEpochStart;
  final int millisSinceEpochEnd;
  final String type;
  final String category;
  final String label;
  final double value;
  final String? currency;
  final double? originalValue;

  const Expense({
    this.id,
    required this.millisSinceEpochStart,
    required this.millisSinceEpochEnd,
    required this.type,
    required this.category,
    required this.label,
    required this.value,
    this.currency,
    this.originalValue,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    final start = _toInt(map['millisSinceEpochStart']);
    return Expense(
      id: map['id'] == null ? null : _toInt(map['id']),
      millisSinceEpochStart: start,
      millisSinceEpochEnd: map['millisSinceEpochEnd'] == null ? start : _toInt(map['millisSinceEpochEnd']),
      type: map['type'].toString(),
      category: map['category'].toString(),
      label: (map['label'] ?? '').toString(),
      value: _toDouble(map['value']),
      currency: map['currency'] as String?,
      originalValue: map['originalValue'] == null ? null : _toDouble(map['originalValue']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'millisSinceEpochStart': millisSinceEpochStart,
      'millisSinceEpochEnd': millisSinceEpochEnd,
      'type': type,
      'category': category,
      'label': label,
      'value': value,
      'currency': currency,
      'originalValue': originalValue,
    };
  }

  Expense copyWith({int? id, double? value, String? currency, double? originalValue}) {
    return Expense(
      id: id ?? this.id,
      millisSinceEpochStart: millisSinceEpochStart,
      millisSinceEpochEnd: millisSinceEpochEnd,
      type: type,
      category: category,
      label: label,
      value: value ?? this.value,
      currency: currency ?? this.currency,
      originalValue: originalValue ?? this.originalValue,
    );
  }

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  DateTime get start => DateTime.fromMillisecondsSinceEpoch(millisSinceEpochStart);
  DateTime get end => DateTime.fromMillisecondsSinceEpoch(millisSinceEpochEnd);

  /// Number of calendar days covered (1 for a single-day entry).
  int get days => Dates.daysBetween(start, end) + 1;
  bool get isPeriod => days > 1;
  double get perDay => value / days;

  @override
  String toString() {
    return 'Expense{id: $id, millisSinceEpoch: $millisSinceEpochStart - $millisSinceEpochEnd, type: $type, category: $category, label: $label value: $value}';
  }

  static int _toInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.parse(v.toString()));
  static double _toDouble(dynamic v) => v is num ? v.toDouble() : double.parse(v.toString().replaceAll(',', '.'));
}
