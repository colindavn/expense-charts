import 'package:expenses_charts/constants/categories.dart';
import 'package:expenses_charts/models/expenses.dart';
import 'package:expenses_charts/pages/entry_sheet.dart';
import 'package:expenses_charts/providers/currency_provider.dart';
import 'package:expenses_charts/providers/expense_store.dart';
import 'package:expenses_charts/theme/app_theme.dart';
import 'package:expenses_charts/theme/tokens.dart';
import 'package:expenses_charts/utils/analytics.dart';
import 'package:expenses_charts/utils/dates.dart';
import 'package:expenses_charts/utils/format.dart';
import 'package:expenses_charts/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  DateTime _month = Dates.monthStart(Dates.now());
  String _filter = 'all';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPicker(initial: _month),
    );
    if (picked != null) setState(() => _month = picked);
  }

  Future<void> _delete(Expense e) async {
    final store = context.read<ExpenseStore>();
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmDelete(context, e.label)) return;
    await store.delete(e);
    messenger.showSnackBar(const SnackBar(content: Text('Entry deleted'), duration: Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final entries = context.watch<ExpenseStore>().entries;
    final currencies = context.watch<CurrencyProvider>();
    final money = currencies.money;

    final list = Analytics.activity(entries, _month, filter: _filter, query: _search.text);
    final groups = Analytics.groupByDay(list);
    final totalIn = list.where((e) => e.isIncome).fold(0.0, (a, e) => a + e.value);
    final totalOut = list.where((e) => e.isExpense).fold(0.0, (a, e) => a + e.value);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        ScreenHeader(
          overline: 'Activity',
          title: DateText.monthYear(_month),
          trailing: PillButton(
            label: 'Month',
            icon: LucideIcons.calendar,
            onTap: _pickMonth,
            background: c.card,
            foreground: c.text,
            border: BorderSide(color: c.divider),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
          child: TextField(
            controller: _search,
            style: AppText.body.copyWith(color: c.text, fontSize: 16),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search labels or amounts',
              hintStyle: AppText.body.copyWith(color: c.faint, fontSize: 16),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 10),
                child: Icon(LucideIcons.search, size: 20, color: c.muted),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 46),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(icon: Icon(LucideIcons.x, size: 18, color: c.muted), onPressed: _search.clear),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
            children: [
              _FilterChip(label: 'All', dot: null, selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
              _FilterChip(
                label: 'Income',
                dot: ExpenseCategories.income.color,
                selected: _filter == 'income',
                onTap: () => setState(() => _filter = 'income'),
              ),
              for (final k in ExpenseCategories.all)
                _FilterChip(
                  label: ExpenseCategories.getDisplayName(k),
                  dot: ExpenseCategories.style(k).color,
                  selected: _filter == k,
                  onTap: () => setState(() => _filter = k),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
          child: AppCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _Summary(label: 'In', value: money.signed(totalIn, income: true), color: c.income),
                  VerticalDivider(width: 1, color: c.divider),
                  _Summary(label: 'Out', value: money.signed(totalOut, income: false), color: c.text),
                  VerticalDivider(width: 1, color: c.divider),
                  _Summary(label: 'Entries', value: '${list.length}', color: c.text),
                ],
              ),
            ),
          ),
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                _search.text.isNotEmpty || _filter != 'all' ? 'No matching entries' : 'No entries this month',
                style: AppText.body.copyWith(color: c.muted),
              ),
            ),
          ),
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.gutter + 4, 22, AppSizes.gutter + 4, 10),
            child: Row(
              children: [
                Expanded(child: Text(DateText.dayHeader(g.day), style: AppText.bodyStrong.copyWith(color: c.muted, fontSize: 14.5))),
                Text(
                  g.expenses > 0 ? money.signed(g.expenses, income: false) : money.signed(g.incomes, income: true),
                  style: AppText.bodyStrong.copyWith(color: c.muted, fontSize: 14.5, fontFeatures: AppFonts.tabular),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Column(
                children: [
                  for (var i = 0; i < g.entries.length; i++) ...[
                    if (i > 0) const CardDivider(),
                    _ActivityRow(
                      entry: g.entries[i],
                      money: money,
                      currencies: currencies,
                      onTap: () => openEntrySheet(context, entry: g.entries[i]),
                      onLongPress: () => _delete(g.entries[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final Expense entry;
  final Money money;
  final CurrencyProvider currencies;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ActivityRow({
    required this.entry,
    required this.money,
    required this.currencies,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final parts = <String>[e.isIncome ? 'Income' : ExpenseCategories.getDisplayName(e.category)];
    if (e.isPeriod) {
      final unit = e.category == 'trip' ? 'night' : 'day';
      parts.add(DateText.range(e.start, e.end));
      parts.add('${e.days} ${unit}s');
      parts.add('${money.fmt(e.perDay)}/$unit');
    }
    if (e.currency != null && e.originalValue != null) {
      final symbol = currencies.byCode(e.currency)?.symbol ?? '${e.currency} ';
      parts.add('$symbol${NumberFormat('#,##0.##', 'en_US').format(e.originalValue)}');
    }
    return EntryRow(
      style: ExpenseCategories.styleFor(e.type, e.category),
      title: e.label,
      subtitle: parts.join(' · '),
      amount: money.signed(e.value, income: e.isIncome),
      income: e.isIncome,
      period: e.isPeriod,
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.symmetric(vertical: 14),
    );
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Summary({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(label, style: AppText.small.copyWith(color: c.muted, fontSize: 13)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(value, style: AppText.itemAmount.copyWith(color: color, fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color? dot;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.dot, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      key: ValueKey('chip-$label'),
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? c.ink : c.card,
        shape: StadiumBorder(side: BorderSide(color: selected ? c.ink : c.divider)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? c.onInk : (dot ?? c.text)),
                ),
                const SizedBox(width: 9),
                Text(label, style: AppText.chip.copyWith(color: selected ? c.onInk : c.text, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Year header with ‹ › and a 3×4 grid of months.
class _MonthPicker extends StatefulWidget {
  final DateTime initial;
  const _MonthPicker({required this.initial});

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final now = Dates.now();
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleIconButton(icon: LucideIcons.chevronLeft, size: 38, onTap: () => setState(() => _year--)),
                Expanded(child: Text('$_year', textAlign: TextAlign.center, style: AppText.sectionTitle.copyWith(color: c.text))),
                CircleIconButton(icon: LucideIcons.chevronRight, size: 38, onTap: () => setState(() => _year++)),
              ],
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var m = 1; m <= 12; m++)
                  Builder(builder: (context) {
                    final d = DateTime(_year, m, 1);
                    final sel = _year == widget.initial.year && m == widget.initial.month;
                    final isNow = _year == now.year && m == now.month;
                    return Material(
                      color: sel ? c.ink : c.field,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context, d),
                        child: Center(
                          child: Text(
                            DateText.monthShort(d),
                            style: AppText.bodyStrong.copyWith(
                              color: sel ? c.onInk : (isNow ? c.text : c.muted),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
