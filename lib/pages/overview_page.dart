import 'dart:math' as math;

import 'package:expenses_charts/constants/categories.dart';
import 'package:expenses_charts/models/expenses.dart';
import 'package:expenses_charts/pages/budget_page.dart';
import 'package:expenses_charts/pages/entry_sheet.dart';
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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

class OverviewPage extends StatefulWidget {
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenActivity;

  const OverviewPage({super.key, required this.onOpenAnalytics, required this.onOpenActivity});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  DateTime _month = Dates.monthStart(Dates.now());

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta, 1));

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<ExpenseStore>().entries;
    final settings = context.watch<SettingsProvider>();
    final money = context.watch<CurrencyProvider>().money;
    final now = Dates.now();
    final start = _month, end = Dates.monthEnd(_month);

    final budget = Analytics.monthBudget(entries, _month, settings.monthlyBudget, now);
    final income = Analytics.total(entries, start, end, type: 'income');
    final categories = Analytics.categoryTotals(entries, start, end);
    final recent = Analytics.activity(entries, _month).take(4).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ScreenHeader(
          overline: 'Overview',
          title: DateText.monthYear(_month),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleIconButton(icon: LucideIcons.chevronLeft, onTap: () => _shift(-1), tooltip: 'Previous month'),
              const SizedBox(width: 10),
              CircleIconButton(icon: LucideIcons.chevronRight, onTap: () => _shift(1), tooltip: 'Next month'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
          child: Column(
            children: [
              _HeroCard(budget: budget, money: money, alert: settings.alertAt80),
              const SizedBox(height: AppSizes.gap),
              Row(
                children: [
                  Expanded(
                    child: _FlowTile(
                      icon: LucideIcons.arrowUpRight,
                      label: 'Income',
                      amount: money.signed(income, income: true),
                      income: true,
                    ),
                  ),
                  const SizedBox(width: AppSizes.gap),
                  Expanded(
                    child: _FlowTile(
                      icon: LucideIcons.arrowDownLeft,
                      label: 'Expenses',
                      amount: money.signed(budget.spent, income: false),
                      income: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.gap),
              _WhereItWent(totals: categories, money: money, onDetails: widget.onOpenAnalytics),
              const SizedBox(height: AppSizes.gap),
              _Recent(entries: recent, money: money, onSeeAll: widget.onOpenActivity),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final MonthBudget budget;
  final Money money;
  final bool alert;

  const _HeroCard({required this.budget, required this.money, required this.alert});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final over = budget.left < 0;
    final pct = (budget.spentFraction * 100).round();
    final ended = budget.daysLeft == 0 && budget.pace >= 1;
    final sub = StringBuffer('of ${money.fmt(budget.budget)} monthly budget');
    if (ended) {
      sub.write(' · month ended');
    } else {
      sub.write(' · ${budget.daysLeft} ${budget.daysLeft == 1 ? 'day' : 'days'} left');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: c.hero,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
        border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: c.heroTrack) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(over ? 'Over budget' : 'Left to spend', style: AppText.body.copyWith(color: c.heroMuted)),
              ),
              PillButton(
                label: 'Edit budget',
                onTap: () => editBudget(context),
                background: c.heroButton,
                foreground: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(money.fmt(budget.left), style: AppText.heroAmount.copyWith(color: Colors.white)),
          ),
          const SizedBox(height: 10),
          Text(sub.toString(), style: AppText.body.copyWith(color: c.heroMuted)),
          const SizedBox(height: 22),
          _ProgressWithPace(fraction: budget.spentFraction, pace: budget.pace, over: over),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${money.fmt(budget.spent)} spent · $pct%',
                  style: AppText.small.copyWith(color: c.heroMuted, fontSize: 13),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: c.amber, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text("Today's even pace", style: AppText.small.copyWith(color: c.heroMuted, fontSize: 13)),
            ],
          ),
          if (alert && budget.spentFraction >= 0.8 && !ended) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(LucideIcons.triangleAlert, size: 16, color: c.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    over ? 'Budget exceeded' : '$pct% of your budget is spent',
                    style: AppText.smallStrong.copyWith(color: c.amber, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
          if (!ended) ...[
            const SizedBox(height: 18),
            Divider(height: 1, color: c.heroTrack),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text('Daily allowance from today', style: AppText.body.copyWith(color: c.heroMuted))),
                Text('${money.fmt(budget.dailyAllowance)} / day', style: AppText.allowance.copyWith(color: Colors.white)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressWithPace extends StatelessWidget {
  final double fraction;
  final double pace;
  final bool over;

  const _ProgressWithPace({required this.fraction, required this.pace, required this.over});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final fill = (fraction.clamp(0.0, 1.0)) * w;
      final marker = (pace.clamp(0.0, 1.0)) * w;
      return SizedBox(
        height: 22,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 6,
              child: Container(height: 10, decoration: BoxDecoration(color: c.heroTrack, borderRadius: BorderRadius.circular(5))),
            ),
            Positioned(
              left: 0,
              top: 6,
              child: Container(
                width: fill,
                height: 10,
                decoration: BoxDecoration(color: over ? c.danger : Colors.white, borderRadius: BorderRadius.circular(5)),
              ),
            ),
            if (pace > 0 && pace < 1)
              Positioned(
                left: math.max(0, marker - 2),
                top: 0,
                child: Container(width: 4, height: 22, decoration: BoxDecoration(color: c.amber, borderRadius: BorderRadius.circular(2))),
              ),
          ],
        ),
      );
    });
  }
}

class _FlowTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String amount;
  final bool income;

  const _FlowTile({required this.icon, required this.label, required this.amount, required this.income});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = income ? c.income : c.text;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 10),
              Text(label, style: AppText.body.copyWith(color: c.muted)),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(amount, style: AppText.tileAmount.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

class _WhereItWent extends StatelessWidget {
  final List<MapEntry<String, double>> totals;
  final Money money;
  final VoidCallback onDetails;

  const _WhereItWent({required this.totals, required this.money, required this.onDetails});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final legend = Analytics.donutLegend(totals);
    final sum = totals.fold(0.0, (a, b) => a + b.value);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      child: Column(
        children: [
          CardHeader(title: 'Where it went', action: 'Details', onAction: onDetails),
          const SizedBox(height: 18),
          if (sum <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No expenses this month', style: AppText.body.copyWith(color: c.muted)),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 128,
                  height: 128,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          startDegreeOffset: -90,
                          sectionsSpace: 2,
                          centerSpaceRadius: 46,
                          borderData: FlBorderData(show: false),
                          pieTouchData: PieTouchData(enabled: false),
                          sections: [
                            for (final t in totals)
                              PieChartSectionData(
                                value: t.value,
                                color: ExpenseCategories.style(t.key).color,
                                radius: 17,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Spent', style: AppText.small.copyWith(color: c.muted)),
                          Text(money.fmt(sum.floorToDouble(), decimals: false), style: AppText.donutCenter.copyWith(color: c.text)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    children: [
                      for (final r in legend.rows)
                        _LegendLine(
                          color: ExpenseCategories.style(r.category).color,
                          label: ExpenseCategories.getDisplayName(r.category),
                          pct: r.share,
                        ),
                      if (legend.othersCount > 0)
                        _LegendLine(
                          color: c.faint.withValues(alpha: 0.7),
                          label: '${legend.othersCount} ${legend.othersCount == 1 ? 'other' : 'others'}',
                          pct: legend.othersShare,
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LegendLine extends StatelessWidget {
  final Color color;
  final String label;
  final double pct;

  const _LegendLine({required this.color, required this.label, required this.pct});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        children: [
          Container(width: 11, height: 11, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppText.body.copyWith(color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text('${(pct * 100).round()}%', style: AppText.bodyStrong.copyWith(color: c.text, fontFeatures: AppFonts.tabular)),
        ],
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  final List<Expense> entries;
  final Money money;
  final VoidCallback onSeeAll;

  const _Recent({required this.entries, required this.money, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 6),
      child: Column(
        children: [
          CardHeader(title: 'Recent', action: 'See all', onAction: onSeeAll),
          const SizedBox(height: 14),
          const CardDivider(),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Text('No entries yet. Tap + to add one.', style: AppText.body.copyWith(color: c.muted)),
            ),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const CardDivider(),
            EntryRow(
              style: ExpenseCategories.styleFor(entries[i].type, entries[i].category),
              title: entries[i].label,
              subtitle: '${entries[i].isIncome ? 'Income' : ExpenseCategories.getDisplayName(entries[i].category)} · ${DateText.relative(entries[i].start)}',
              amount: money.signed(entries[i].value, income: entries[i].isIncome),
              income: entries[i].isIncome,
              onTap: () => openEntrySheet(context, entry: entries[i]),
            ),
          ],
        ],
      ),
    );
  }
}
