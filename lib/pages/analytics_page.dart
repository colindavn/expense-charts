import 'dart:math' as math;

import 'package:expenses_charts/constants/categories.dart';
import 'package:expenses_charts/providers/currency_provider.dart';
import 'package:expenses_charts/providers/expense_store.dart';
import 'package:expenses_charts/providers/settings.dart';
import 'package:expenses_charts/theme/app_theme.dart';
import 'package:expenses_charts/theme/tokens.dart';
import 'package:expenses_charts/utils/analytics.dart';
import 'package:expenses_charts/utils/dates.dart';
import 'package:expenses_charts/utils/format.dart';
import 'package:expenses_charts/widgets/common.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  ChartPeriod _period = ChartPeriod.daily;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<ExpenseStore>().entries;
    final settings = context.watch<SettingsProvider>();
    final money = context.watch<CurrencyProvider>().money;
    final now = Dates.now();

    final buckets = Analytics.buckets(entries, _period, now, weekStartsOn: settings.weekStartsOn);
    final stats = Analytics.stats(buckets);
    final selected = (_selected ?? buckets.length - 1).clamp(0, buckets.length - 1);

    // "By category" covers the current month for daily/weekly, the year for monthly, everything for yearly.
    final (DateTime, DateTime, String) catRange = switch (_period) {
      ChartPeriod.daily || ChartPeriod.weekly => (Dates.monthStart(now), Dates.monthEnd(now), DateText.monthName(now)),
      ChartPeriod.monthly => (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31), '${now.year}'),
      ChartPeriod.yearly => (buckets.first.start, buckets.last.end, 'All time'),
    };
    final categories = Analytics.categoryTotals(entries, catRange.$1, catRange.$2);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const ScreenHeader(overline: 'Analytics', title: 'Spending over time'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
          child: Column(
            children: [
              PillSegmented<ChartPeriod>(
                values: ChartPeriod.values,
                selected: _period,
                label: (p) => p.label,
                dark: true,
                height: 52,
                onChanged: (p) => setState(() {
                  _period = p;
                  _selected = null;
                }),
              ),
              const SizedBox(height: 16),
              _ChartCard(
                period: _period,
                buckets: buckets,
                stats: stats,
                selected: selected,
                money: money,
                onSelect: (i) => setState(() => _selected = i),
              ),
              const SizedBox(height: AppSizes.gap + 2),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Average',
                      value: money.fmt(stats.average),
                      sub: _period.unit,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: 'Highest',
                      value: stats.highest == null ? '—' : money.fmt(stats.highest!.total),
                      sub: stats.highest == null ? ' ' : _shortLabel(stats.highest!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: 'Lowest',
                      value: stats.lowest == null ? '—' : money.fmt(stats.lowest!.total),
                      sub: stats.lowest == null ? ' ' : _shortLabel(stats.lowest!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.gap + 2),
              _ByCategory(totals: categories, rangeName: catRange.$3, money: money),
            ],
          ),
        ),
      ],
    );
  }

  String _shortLabel(Bucket b) => switch (_period) {
        ChartPeriod.daily => DateText.dayLong(b.start),
        ChartPeriod.weekly => DateText.range(b.start, b.end),
        ChartPeriod.monthly => '${DateText.monthShort(b.start)} ${b.start.year}',
        ChartPeriod.yearly => '${b.start.year}',
      };
}

class _ChartCard extends StatelessWidget {
  final ChartPeriod period;
  final List<Bucket> buckets;
  final BucketStats stats;
  final int selected;
  final Money money;
  final ValueChanged<int> onSelect;

  const _ChartCard({
    required this.period,
    required this.buckets,
    required this.stats,
    required this.selected,
    required this.money,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final sel = buckets[selected];
    final maxTotal = buckets.fold(0.0, (a, b) => math.max(a, b.total));
    final maxY = math.max(maxTotal, stats.average) * 1.06;
    final safeMaxY = maxY <= 0 ? 1.0 : maxY;
    final minBar = safeMaxY * 0.04;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(period.rangeLabel(buckets.length), style: AppText.body.copyWith(color: c.muted)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(money.fmt(stats.total), style: AppText.bigAmount.copyWith(color: c.text)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: c.field, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(sel.longLabel, style: AppText.small.copyWith(color: c.muted, fontSize: 13)),
                    const SizedBox(height: 1),
                    Text(money.fmt(sel.total), style: AppText.statAmount.copyWith(color: c.text)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 200,
            child: LayoutBuilder(builder: (context, box) {
              final slot = box.maxWidth / buckets.length;
              final barWidth = math.min(24.0, slot * 0.66);
              return BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: safeMaxY,
                  minY: 0,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                          final isSel = i == selected;
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              buckets[i].axisLabel,
                              style: AppText.small.copyWith(
                                fontSize: buckets.length > 12 ? 13 : 11.5,
                                color: isSel ? c.text : c.muted,
                                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (stats.average > 0)
                        HorizontalLine(
                          y: stats.average,
                          color: c.amber,
                          strokeWidth: 1.3,
                          dashArray: [5, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(bottom: 3),
                            style: AppText.smallStrong.copyWith(color: c.amberText, fontSize: 12.5),
                            labelResolver: (_) => 'avg ${money.fmt(stats.average)}',
                          ),
                        ),
                    ],
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    handleBuiltInTouches: false,
                    allowTouchBarBackDraw: true,
                    touchCallback: (event, response) {
                      final spot = response?.spot;
                      if (event is FlTapUpEvent && spot != null) onSelect(spot.touchedBarGroupIndex);
                    },
                  ),
                  barGroups: [
                    for (var i = 0; i < buckets.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: math.max(buckets[i].total, minBar),
                            width: barWidth,
                            color: i == selected ? c.ink : c.barIdle,
                            borderRadius: BorderRadius.circular(6),
                            backDrawRodData: BackgroundBarChartRodData(show: true, toY: safeMaxY, color: Colors.transparent),
                          ),
                        ],
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 250),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;

  const _StatTile({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.small.copyWith(color: c.muted, fontSize: 13)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.statAmount.copyWith(color: c.text, fontSize: 17)),
          ),
          const SizedBox(height: 3),
          Text(sub, style: AppText.small.copyWith(color: c.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ByCategory extends StatelessWidget {
  final List<MapEntry<String, double>> totals;
  final String rangeName;
  final Money money;

  const _ByCategory({required this.totals, required this.rangeName, required this.money});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final max = totals.isEmpty ? 1.0 : totals.first.value;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      child: Column(
        children: [
          CardHeader(
            title: 'By category',
            trailing: Text(rangeName, style: AppText.body.copyWith(color: c.muted, fontSize: 14)),
          ),
          if (totals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Text('No expenses yet', style: AppText.body.copyWith(color: c.muted)),
            ),
          for (final t in totals) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Text(ExpenseCategories.getDisplayName(t.key), style: AppText.body.copyWith(color: c.text, fontSize: 15.5))),
                Text(money.fmt(t.value), style: AppText.bodyStrong.copyWith(color: c.text, fontSize: 15.5, fontFeatures: AppFonts.tabular)),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, box) {
              return Stack(
                children: [
                  Container(height: 8, decoration: BoxDecoration(color: c.track, borderRadius: BorderRadius.circular(4))),
                  Container(
                    height: 8,
                    width: box.maxWidth * (t.value / max).clamp(0.0, 1.0),
                    decoration: BoxDecoration(color: ExpenseCategories.style(t.key).color, borderRadius: BorderRadius.circular(4)),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}
