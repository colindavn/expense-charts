import 'package:expenses_charts/models/expenses.dart';
import 'package:expenses_charts/utils/analytics.dart';
import 'package:expenses_charts/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

Expense entry(String category, double value, DateTime start, {DateTime? end, String type = 'expense', String label = 'x', int? id}) {
  return Expense(
    id: id,
    millisSinceEpochStart: DateTime(start.year, start.month, start.day, 12).millisecondsSinceEpoch,
    millisSinceEpochEnd: DateTime((end ?? start).year, (end ?? start).month, (end ?? start).day, 12).millisecondsSinceEpoch,
    type: type,
    category: type == 'income' ? 'income' : category,
    label: label,
    value: value,
  );
}

void main() {
  final today = DateTime(2026, 11, 10, 15);

  group('Month budget (mockup numbers)', () {
    final entries = [
      entry('regular', 412.30, DateTime(2026, 11, 1)),
      entry('grocery', 236.45, DateTime(2026, 11, 2)),
      entry('trip', 210.00, DateTime(2026, 11, 7), end: DateTime(2026, 11, 9)),
      entry('restaurant', 148.20, DateTime(2026, 11, 9)),
      entry('leisure', 96.50, DateTime(2026, 11, 8)),
      entry('health', 54.90, DateTime(2026, 11, 9)),
      entry('exceptional', 52.00, DateTime(2026, 11, 3)),
      entry('alcohol', 38.25, DateTime(2026, 11, 8)),
      entry('', 2450, DateTime(2026, 11, 6), type: 'income'),
      entry('grocery', 999, DateTime(2026, 10, 30)), // other month
    ];

    test('left to spend, days left, allowance and pace', () {
      final b = Analytics.monthBudget(entries, DateTime(2026, 11), 1800, today);
      expect(b.spent, closeTo(1248.60, 0.001));
      expect(b.left, closeTo(551.40, 0.001));
      expect(b.daysLeft, 20);
      expect(b.dailyAllowance, closeTo(27.57, 0.005));
      expect((b.spentFraction * 100).round(), 69);
      expect(b.pace, closeTo(1 / 3, 0.0001));
    });

    test('income is counted separately', () {
      expect(Analytics.total(entries, DateTime(2026, 11, 1), DateTime(2026, 11, 30), type: 'income'), 2450);
    });

    test('past month has no days left', () {
      final b = Analytics.monthBudget(entries, DateTime(2026, 10), 1800, today);
      expect(b.daysLeft, 0);
      expect(b.pace, 1);
      expect(b.dailyAllowance, 0);
    });

    test('donut legend: top 4 + others', () {
      final totals = Analytics.categoryTotals(entries, DateTime(2026, 11, 1), DateTime(2026, 11, 30));
      expect(totals.first.key, 'regular');
      final legend = Analytics.donutLegend(totals);
      expect(legend.rows.map((r) => r.category), ['regular', 'grocery', 'trip', 'restaurant']);
      expect(legend.othersCount, 4);
      expect((legend.rows.first.share * 100).round(), 33);
      expect((legend.othersShare * 100).round(), 19);
    });
  });

  test('a period entry is spread over its days and clipped to the range', () {
    final hotel = entry('trip', 210, DateTime(2026, 10, 31), end: DateTime(2026, 11, 2));
    final daily = Analytics.dailyTotals([hotel], DateTime(2026, 11, 1), DateTime(2026, 11, 30));
    expect(daily.length, 2);
    expect(daily[DateTime(2026, 11, 1)], 70);
    expect(Analytics.total([hotel], DateTime(2026, 11, 1), DateTime(2026, 11, 30)), 140);
  });

  test('daily buckets: 14 bars ending today, average includes empty days', () {
    final entries = [
      entry('grocery', 27.50, DateTime(2026, 11, 10)),
      entry('regular', 140, DateTime(2026, 11, 1)),
      entry('regular', 1, DateTime(2026, 10, 27)), // just outside the 14 days
    ];
    final buckets = Analytics.buckets(entries, ChartPeriod.daily, today);
    expect(buckets.length, 14);
    expect(buckets.first.axisLabel, '28');
    expect(buckets.last.axisLabel, '10');
    expect(buckets.last.total, 27.5);
    final stats = Analytics.stats(buckets);
    expect(stats.total, 167.5);
    expect(stats.average, closeTo(167.5 / 14, 0.0001));
    expect(stats.highest!.total, 140);
    expect(stats.lowest!.total, 27.5);
  });

  test('weekly buckets respect the week start', () {
    final monday = Analytics.buckets(const [], ChartPeriod.weekly, today);
    expect(monday.last.start, DateTime(2026, 11, 9)); // Monday
    final sunday = Analytics.buckets(const [], ChartPeriod.weekly, today, weekStartsOn: DateTime.sunday);
    expect(sunday.last.start, DateTime(2026, 11, 8));
    expect(monday.length, 8);
  });

  test('monthly and yearly buckets', () {
    final months = Analytics.buckets(const [], ChartPeriod.monthly, today);
    expect(months.length, 12);
    expect(months.first.start, DateTime(2025, 12, 1));
    final years = Analytics.buckets([entry('regular', 5, DateTime(2024, 3, 1))], ChartPeriod.yearly, today);
    expect(years.map((b) => b.axisLabel), ['2024', '2025', '2026']);
  });

  test('activity: month, filters, search and grouping', () {
    final entries = [
      entry('grocery', 27.50, DateTime(2026, 11, 10), label: 'Groceries', id: 1),
      entry('restaurant', 42.80, DateTime(2026, 11, 9), label: 'Dinner out', id: 2),
      entry('health', 18.40, DateTime(2026, 11, 9), label: 'Pharmacy', id: 3),
      entry('', 2450, DateTime(2026, 11, 6), type: 'income', label: 'Salary', id: 4),
      entry('grocery', 12, DateTime(2026, 10, 9), label: 'Old', id: 5),
    ];
    final month = DateTime(2026, 11);
    expect(Analytics.activity(entries, month).length, 4);
    expect(Analytics.activity(entries, month, filter: 'income').single.label, 'Salary');
    expect(Analytics.activity(entries, month, filter: 'grocery').single.label, 'Groceries');
    expect(Analytics.activity(entries, month, query: 'dinner').single.id, 2);
    expect(Analytics.activity(entries, month, query: '18,4').single.id, 3);

    final groups = Analytics.groupByDay(Analytics.activity(entries, month));
    expect(groups.length, 3);
    expect(groups[1].entries.length, 2);
    expect(groups[1].expenses, closeTo(61.20, 0.001));
  });

  test('money and date formatting', () {
    const m = Money('€');
    expect(m.fmt(1248.6), '€1,248.60');
    expect(m.fmt(-12), '$minus€12.00');
    expect(m.fmt(1248.6, decimals: false), '€1,249');
    expect(m.signed(27.5, income: false), '$minus€27.50');
    expect(m.signed(2450, income: true), '+€2,450.00');
    expect(DateText.dayHeader(DateTime(2026, 11, 10), now: today), 'Today · Tue 10 Nov');
    expect(DateText.dayHeader(DateTime(2026, 11, 8), now: today), 'Sun 8 Nov');
    expect(DateText.range(DateTime(2026, 11, 7), DateTime(2026, 11, 9)), '7–9 Nov');
  });
}
