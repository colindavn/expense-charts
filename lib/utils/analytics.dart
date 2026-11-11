import 'package:expenses_charts/models/expenses.dart';
import 'package:expenses_charts/utils/dates.dart';
import 'package:expenses_charts/utils/format.dart';

/// Pure calculations behind every screen. A period entry counts
/// value / days on each day it covers.
class Analytics {
  Analytics._();

  /// Total per day between [from] and [to] (inclusive), keyed by local midnight.
  static Map<DateTime, double> dailyTotals(
    Iterable<Expense> entries,
    DateTime from,
    DateTime to, {
    String type = 'expense',
    String? category,
  }) {
    final out = <DateTime, double>{};
    final f = Dates.dateOnly(from), t = Dates.dateOnly(to);
    for (final e in entries) {
      if (e.type != type) continue;
      if (category != null && e.category != category) continue;
      final s = Dates.dateOnly(e.start);
      final days = e.days;
      final perDay = e.value / days;
      for (var i = 0; i < days; i++) {
        final d = Dates.addDays(s, i);
        if (d.isBefore(f) || d.isAfter(t)) continue;
        out[d] = (out[d] ?? 0) + perDay;
      }
    }
    return out;
  }

  static double total(Iterable<Expense> entries, DateTime from, DateTime to, {String type = 'expense'}) =>
      dailyTotals(entries, from, to, type: type).values.fold(0.0, (a, b) => a + b);

  /// Expense total per category between [from] and [to], largest first.
  static List<MapEntry<String, double>> categoryTotals(Iterable<Expense> entries, DateTime from, DateTime to) {
    final f = Dates.dateOnly(from), t = Dates.dateOnly(to);
    final out = <String, double>{};
    for (final e in entries) {
      if (!e.isExpense) continue;
      final s = Dates.dateOnly(e.start);
      final perDay = e.value / e.days;
      for (var i = 0; i < e.days; i++) {
        final d = Dates.addDays(s, i);
        if (d.isBefore(f) || d.isAfter(t)) continue;
        out[e.category] = (out[e.category] ?? 0) + perDay;
      }
    }
    final list = out.entries.where((e) => e.value > 0.0049).toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  /// Legend rows for the donut: the [top] largest categories, then "others".
  static DonutLegend donutLegend(List<MapEntry<String, double>> totals, {int top = 4}) {
    final sum = totals.fold(0.0, (a, b) => a + b.value);
    if (sum <= 0) return const DonutLegend([], 0, 0, 0);
    final head = totals.take(top).map((e) => LegendRow(e.key, e.value, e.value / sum)).toList();
    final rest = totals.skip(top).toList();
    final restSum = rest.fold(0.0, (a, b) => a + b.value);
    return DonutLegend(head, rest.length, restSum, restSum / sum);
  }

  /// Budget figures for one month, as seen on [today].
  static MonthBudget monthBudget(Iterable<Expense> entries, DateTime month, double budget, DateTime today) {
    final start = Dates.monthStart(month), end = Dates.monthEnd(month);
    final spent = total(entries, start, end);
    final daysInMonth = end.day;
    final int daysLeft;
    final double pace;
    if (today.isBefore(start)) {
      daysLeft = daysInMonth;
      pace = 0;
    } else if (Dates.dateOnly(today).isAfter(end)) {
      daysLeft = 0;
      pace = 1;
    } else {
      daysLeft = daysInMonth - today.day;
      pace = today.day / daysInMonth;
    }
    return MonthBudget(budget: budget, spent: spent, daysLeft: daysLeft, pace: pace);
  }

  /// Bars for the Analytics chart, oldest first. The last bar contains [now].
  static List<Bucket> buckets(Iterable<Expense> entries, ChartPeriod period, DateTime now, {int weekStartsOn = DateTime.monday}) {
    final today = Dates.dateOnly(now);
    final ranges = <(DateTime, DateTime, String, String)>[];
    switch (period) {
      case ChartPeriod.daily:
        for (var i = 13; i >= 0; i--) {
          final d = Dates.addDays(today, -i);
          ranges.add((d, d, '${d.day}', DateText.dayLong(d)));
        }
      case ChartPeriod.weekly:
        final current = Dates.weekStart(today, weekStartsOn);
        for (var i = 7; i >= 0; i--) {
          final s = Dates.addDays(current, -7 * i);
          final e = Dates.addDays(s, 6);
          ranges.add((s, e, '${s.day}/${s.month}', DateText.range(s, e)));
        }
      case ChartPeriod.monthly:
        for (var i = 11; i >= 0; i--) {
          final s = DateTime(today.year, today.month - i, 1);
          ranges.add((s, Dates.monthEnd(s), DateText.monthShort(s), DateText.monthYear(s)));
        }
      case ChartPeriod.yearly:
        var first = today.year;
        for (final e in entries) {
          if (e.start.year < first) first = e.start.year;
        }
        first = first < today.year - 7 ? today.year - 7 : first;
        for (var y = first; y <= today.year; y++) {
          ranges.add((DateTime(y, 1, 1), DateTime(y, 12, 31), '$y', '$y'));
        }
    }
    final daily = dailyTotals(entries, ranges.first.$1, ranges.last.$2);
    return ranges.map((r) {
      var sum = 0.0;
      daily.forEach((d, v) {
        if (!d.isBefore(r.$1) && !d.isAfter(r.$2)) sum += v;
      });
      return Bucket(start: r.$1, end: r.$2, axisLabel: r.$3, longLabel: r.$4, total: sum);
    }).toList();
  }

  static BucketStats stats(List<Bucket> buckets) {
    if (buckets.isEmpty) return const BucketStats(0, 0, null, null);
    final total = buckets.fold(0.0, (a, b) => a + b.total);
    Bucket? hi, lo;
    for (final b in buckets) {
      if (b.total <= 0) continue;
      if (hi == null || b.total > hi.total) hi = b;
      if (lo == null || b.total < lo.total) lo = b;
    }
    return BucketStats(total, total / buckets.length, hi, lo);
  }

  /// Entries whose start date falls in [month], newest first, matching the filters.
  static List<Expense> activity(
    Iterable<Expense> entries,
    DateTime month, {
    String filter = 'all',
    String query = '',
  }) {
    final q = query.trim().toLowerCase().replaceAll(',', '.');
    return entries.where((e) {
      if (e.start.year != month.year || e.start.month != month.month) return false;
      if (filter == 'income' && !e.isIncome) return false;
      if (filter != 'all' && filter != 'income' && (e.isIncome || e.category != filter)) return false;
      if (q.isEmpty) return true;
      if (e.label.toLowerCase().contains(q)) return true;
      if (e.value.toStringAsFixed(2).contains(q)) return true;
      if (e.originalValue != null && e.originalValue!.toStringAsFixed(2).contains(q)) return true;
      return false;
    }).toList()
      ..sort((a, b) {
        final c = b.millisSinceEpochStart.compareTo(a.millisSinceEpochStart);
        return c != 0 ? c : (b.id ?? 0).compareTo(a.id ?? 0);
      });
  }

  /// Groups a newest-first list by start day.
  static List<DayGroup> groupByDay(List<Expense> entries) {
    final groups = <DayGroup>[];
    for (final e in entries) {
      final d = Dates.dateOnly(e.start);
      if (groups.isEmpty || !Dates.sameDay(groups.last.day, d)) groups.add(DayGroup(d, []));
      groups.last.entries.add(e);
    }
    return groups;
  }
}

enum ChartPeriod { daily, weekly, monthly, yearly }

extension ChartPeriodText on ChartPeriod {
  String get label => const ['Daily', 'Weekly', 'Monthly', 'Yearly'][index];
  String get unit => const ['per day', 'per week', 'per month', 'per year'][index];
  String rangeLabel(int count) => switch (this) {
        ChartPeriod.daily => 'Last $count days',
        ChartPeriod.weekly => 'Last $count weeks',
        ChartPeriod.monthly => 'Last $count months',
        ChartPeriod.yearly => count == 1 ? 'This year' : 'Last $count years',
      };
}

class Bucket {
  final DateTime start, end;
  final String axisLabel, longLabel;
  final double total;
  const Bucket({required this.start, required this.end, required this.axisLabel, required this.longLabel, required this.total});
}

class BucketStats {
  final double total, average;
  final Bucket? highest, lowest;
  const BucketStats(this.total, this.average, this.highest, this.lowest);
}

class LegendRow {
  final String category;
  final double value, share;
  const LegendRow(this.category, this.value, this.share);
}

class DonutLegend {
  final List<LegendRow> rows;
  final int othersCount;
  final double othersValue, othersShare;
  const DonutLegend(this.rows, this.othersCount, this.othersValue, this.othersShare);
}

class MonthBudget {
  final double budget, spent;
  final int daysLeft;

  /// Fraction of the month elapsed (position of the "even pace" marker).
  final double pace;

  const MonthBudget({required this.budget, required this.spent, required this.daysLeft, required this.pace});

  double get left => budget - spent;
  double get spentFraction => budget <= 0 ? 0 : spent / budget;
  double get dailyAllowance => daysLeft <= 0 ? 0 : (left > 0 ? left / daysLeft : 0);
}

class DayGroup {
  final DateTime day;
  final List<Expense> entries;
  DayGroup(this.day, this.entries);

  double get expenses => entries.where((e) => e.isExpense).fold(0.0, (a, e) => a + e.value);
  double get incomes => entries.where((e) => e.isIncome).fold(0.0, (a, e) => a + e.value);
}
