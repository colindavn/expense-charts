import 'package:expenses_charts/utils/dates.dart';
import 'package:intl/intl.dart';

const String minus = '−';

/// Money formatting: "€1,248.60", "−€27.50", "+€2,450.00".
class Money {
  final String symbol;
  const Money(this.symbol);

  static final _two = NumberFormat('#,##0.00', 'en_US');
  static final _zero = NumberFormat('#,##0', 'en_US');

  String fmt(double v, {bool decimals = true}) =>
      '${v < 0 ? minus : ''}$symbol${(decimals ? _two : _zero).format(v.abs())}';

  /// Signed amount for an entry: green "+" for income, "−" for expenses.
  String signed(double v, {required bool income}) => '${income ? '+' : minus}$symbol${_two.format(v.abs())}';

  /// Number typed in an amount field, without symbol or grouping.
  static String plain(double v) => v.toStringAsFixed(2);
}

class DateText {
  DateText._();

  static final _monthYear = DateFormat('MMMM yyyy', 'en_US');
  static final _dayLong = DateFormat('EEE d MMM', 'en_US');
  static final _dayShort = DateFormat('d MMM', 'en_US');
  static final _month = DateFormat('MMM', 'en_US');

  static String monthYear(DateTime d) => _monthYear.format(d);
  static String monthName(DateTime d) => DateFormat('MMMM', 'en_US').format(d);
  static String dayLong(DateTime d) => _dayLong.format(d); // Tue 10 Nov
  static String dayShort(DateTime d) => _dayShort.format(d); // 10 Nov
  static String monthShort(DateTime d) => _month.format(d); // Nov

  /// "Today", "Yesterday" or "Sun 8 Nov".
  static String relative(DateTime d, {DateTime? now}) {
    final today = now ?? Dates.now();
    final diff = Dates.daysBetween(d, today);
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return dayLong(d);
  }

  /// "Today · Tue 10 Nov", "Yesterday · Mon 9 Nov" or "Sun 8 Nov".
  static String dayHeader(DateTime d, {DateTime? now}) {
    final rel = relative(d, now: now);
    return rel == 'Today' || rel == 'Yesterday' ? '$rel · ${dayLong(d)}' : dayLong(d);
  }

  /// "7–9 Nov", or "28 Oct–2 Nov" across months.
  static String range(DateTime a, DateTime b) {
    if (a.month == b.month && a.year == b.year) return '${a.day}–${b.day} ${monthShort(b)}';
    return '${dayShort(a)}–${dayShort(b)}';
  }
}
