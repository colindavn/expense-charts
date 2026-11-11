import 'package:expenses_charts/constants/categories.dart';
import 'package:expenses_charts/models/currency.dart';
import 'package:expenses_charts/models/expenses.dart';
import 'package:expenses_charts/providers/currency_provider.dart';
import 'package:expenses_charts/providers/expense_store.dart';
import 'package:expenses_charts/providers/settings.dart';
import 'package:expenses_charts/theme/app_theme.dart';
import 'package:expenses_charts/theme/tokens.dart';
import 'package:expenses_charts/utils/analytics.dart';
import 'package:expenses_charts/utils/dates.dart';
import 'package:expenses_charts/utils/format.dart';
import 'package:expenses_charts/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

/// Opens the full-screen "New entry" form, or "Edit entry" when [entry] is given.
Future<void> openEntrySheet(BuildContext context, {Expense? entry}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: AppColors.of(context).card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.cardRadius))),
    builder: (_) => EntrySheet(entry: entry),
  );
}

enum _When { oneDay, period }

class EntrySheet extends StatefulWidget {
  final Expense? entry;
  const EntrySheet({super.key, this.entry});

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  late String _type;
  late String _category;
  late String _currency;
  late _When _when;
  late DateTime _start;
  late DateTime _end;
  final _amount = TextEditingController();
  final _label = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final currencies = context.read<CurrencyProvider>();
    final e = widget.entry;
    final today = Dates.dateOnly(Dates.now());
    _type = e?.type ?? 'expense';
    _category = (e != null && ExpenseCategories.isValid(e.category)) ? e.category : 'grocery';
    final typedIn = e?.currency != null && currencies.byCode(e!.currency) != null ? e.currency! : currencies.preferredCode;
    _currency = typedIn;
    _start = e != null ? Dates.dateOnly(e.start) : today;
    _end = e != null ? Dates.dateOnly(e.end) : today;
    _when = (e?.isPeriod ?? false) ? _When.period : _When.oneDay;
    if (e != null) {
      final shown = (e.currency != null && e.originalValue != null && typedIn == e.currency) ? e.originalValue! : e.value;
      _amount.text = Money.plain(shown);
      _label.text = e.label;
    }
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _label.dispose();
    super.dispose();
  }

  double? get _typedAmount {
    final v = double.tryParse(_amount.text.replaceAll(',', '.').replaceAll(' ', ''));
    return (v == null || v <= 0) ? null : v;
  }

  int get _days => _when == _When.period ? Dates.daysBetween(_start, _end) + 1 : 1;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _start = _end = Dates.dateOnly(picked));
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _start, end: _end.isBefore(_start) ? _start : _end),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _start = Dates.dateOnly(picked.start);
        _end = Dates.dateOnly(picked.end);
      });
    }
  }

  Future<void> _pickCurrency() async {
    final provider = context.read<CurrencyProvider>();
    final c = AppColors.of(context);
    final code = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.card,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 18),
            Text('Currency', style: AppText.sectionTitle.copyWith(color: c.text)),
            const SizedBox(height: 8),
            for (final cur in provider.currencies)
              ListTile(
                title: Text('${cur.code}  ${cur.symbol}', style: AppText.bodyStrong.copyWith(color: c.text)),
                subtitle: cur.code == provider.preferredCode
                    ? Text('Preferred', style: AppText.small.copyWith(color: c.muted))
                    : Text('1 ${provider.preferred.symbol} = ${_rate(cur.rate)} ${cur.symbol}', style: AppText.small.copyWith(color: c.muted)),
                trailing: cur.code == _currency ? Icon(LucideIcons.check, color: c.text, size: 20) : null,
                onTap: () => Navigator.pop(ctx, cur.code),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (code != null) setState(() => _currency = code);
  }

  Future<void> _save() async {
    final amount = _typedAmount;
    if (amount == null || _saving) return;
    setState(() => _saving = true);
    final store = context.read<ExpenseStore>();
    final currencies = context.read<CurrencyProvider>();
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final foreign = _currency != currencies.preferredCode;
    final value = foreign ? currencies.toPreferred(amount, _currency) : amount;
    final isIncome = _type == 'income';
    final label = _label.text.trim().isEmpty
        ? (isIncome ? 'Income' : ExpenseCategories.getDisplayName(_category))
        : _label.text.trim();
    final end = _when == _When.period && !_end.isBefore(_start) ? _end : _start;

    final entry = Expense(
      id: widget.entry?.id,
      millisSinceEpochStart: Dates.atNoon(_start).millisecondsSinceEpoch,
      millisSinceEpochEnd: Dates.atNoon(end).millisecondsSinceEpoch,
      type: _type,
      category: isIncome ? 'income' : _category,
      label: label,
      value: value,
      currency: foreign ? _currency : null,
      originalValue: foreign ? amount : null,
    );

    final today = Dates.now();
    final before = Analytics.monthBudget(store.entries, _start, settings.monthlyBudget, today).spentFraction;
    try {
      await store.save(entry);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
      return;
    }
    final after = Analytics.monthBudget(store.entries, _start, settings.monthlyBudget, today).spentFraction;

    navigator.pop();
    if (settings.alertAt80 && before < 0.8 && after >= 0.8) {
      messenger.showSnackBar(SnackBar(content: Text("You've spent ${(after * 100).round()}% of this month's budget")));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Entry updated' : (isIncome ? 'Income saved' : 'Expense saved')),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _delete() async {
    final entry = widget.entry;
    if (entry == null) return;
    final store = context.read<ExpenseStore>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await confirmDelete(context, entry.label);
    if (!ok) return;
    await store.delete(entry);
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Entry deleted'), duration: Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final currencies = context.watch<CurrencyProvider>();
    final Currency cur = currencies.byCode(_currency) ?? currencies.preferred;
    final money = currencies.money;
    final isIncome = _type == 'income';
    final amount = _typedAmount;
    final foreign = _currency != currencies.preferredCode;
    final valueInPreferred = amount == null ? null : (foreign ? currencies.toPreferred(amount, _currency) : amount);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  CircleIconButton(icon: LucideIcons.x, filled: true, onTap: () => Navigator.pop(context), tooltip: 'Close'),
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit entry' : 'New entry',
                      textAlign: TextAlign.center,
                      style: AppText.sectionTitle.copyWith(color: c.text, fontSize: 18),
                    ),
                  ),
                  if (_isEdit)
                    CircleIconButton(icon: LucideIcons.trash2, filled: true, onTap: _delete, tooltip: 'Delete')
                  else
                    const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  PillSegmented<String>(
                    values: const ['expense', 'income'],
                    selected: _type,
                    label: (v) => v == 'expense' ? 'Expense' : 'Income',
                    onChanged: (v) => setState(() => _type = v),
                  ),
                  const SizedBox(height: 28),
                  Center(child: Text('Amount', style: AppText.body.copyWith(color: c.muted))),
                  const SizedBox(height: 6),
                  _AmountField(
                    controller: _amount,
                    symbol: cur.symbol,
                    autofocus: !_isEdit,
                    onSymbolTap: currencies.currencies.length > 1 ? _pickCurrency : null,
                  ),
                  if (foreign && valueInPreferred != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '≈ ${money.fmt(valueInPreferred)} · 1 ${currencies.preferred.symbol} = ${_rate(cur.rate)} ${cur.symbol}',
                        textAlign: TextAlign.center,
                        style: AppText.small.copyWith(color: c.muted),
                      ),
                    ),
                  const SizedBox(height: 22),
                  _FieldLabel('Label'),
                  TextField(
                    controller: _label,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppText.body.copyWith(color: c.text, fontSize: 16),
                    decoration: InputDecoration(hintText: isIncome ? 'Salary' : 'Dinner out'),
                  ),
                  if (!isIncome) ...[
                    const SizedBox(height: 20),
                    _FieldLabel('Category'),
                    _CategoryGrid(selected: _category, onSelect: (k) => setState(() => _category = k)),
                  ],
                  const SizedBox(height: 20),
                  _FieldLabel('When'),
                  PillSegmented<_When>(
                    values: _When.values,
                    selected: _when,
                    label: (v) => v == _When.oneDay ? 'One day' : 'Over a period',
                    onChanged: (v) => setState(() {
                      _when = v;
                      if (v == _When.period && !_end.isAfter(_start)) _end = Dates.addDays(_start, 2);
                      if (v == _When.oneDay) _end = _start;
                    }),
                  ),
                  const SizedBox(height: 10),
                  _DateRow(
                    text: _when == _When.oneDay
                        ? DateText.dayHeader(_start)
                        : '${DateText.dayLong(_start)} → ${DateText.dayLong(_end)}',
                    onTap: _when == _When.oneDay ? _pickDate : _pickRange,
                  ),
                  if (_when == _When.period)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, left: 4),
                      child: Text(
                        valueInPreferred == null
                            ? '$_days days · charts count the amount per day'
                            : '$_days days → ${money.fmt(valueInPreferred / _days)}/day',
                        style: AppText.small.copyWith(color: c.muted, fontSize: 13.5),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.paddingOf(context).bottom),
              child: PrimaryButton(
                label: _isEdit ? 'Save changes' : (isIncome ? 'Save income' : 'Save expense'),
                onPressed: amount == null || _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _rate(double r) => r >= 100 ? r.toStringAsFixed(0) : (r >= 1 ? r.toStringAsFixed(2) : r.toStringAsFixed(4));

/// Asks before deleting an entry.
Future<bool> confirmDelete(BuildContext context, String label) async {
  final c = AppColors.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete entry?'),
      content: Text('"$label" will be removed.', style: AppText.body.copyWith(color: c.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Delete', style: AppText.bodyStrong.copyWith(color: c.danger)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: AppText.body.copyWith(color: AppColors.of(context).muted)),
      );
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String symbol;
  final bool autofocus;
  final VoidCallback? onSymbolTap;

  const _AmountField({required this.controller, required this.symbol, required this.autofocus, this.onSymbolTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final symbolText = Text(symbol, style: AppText.amountInput.copyWith(fontSize: 30, color: c.text));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (onSymbolTap == null)
          symbolText
        else
          Tooltip(
            message: 'Change currency',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onSymbolTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    symbolText,
                    Icon(LucideIcons.chevronDown, size: 14, color: c.muted),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(width: 2),
        IntrinsicWidth(
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            textAlign: TextAlign.left,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: AppText.amountInput.copyWith(color: c.text),
            cursorColor: c.text,
            decoration: InputDecoration(
              filled: false,
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: '0.00',
              hintStyle: AppText.amountInput.copyWith(color: c.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _CategoryGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final b = Theme.of(context).brightness;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 9,
      crossAxisSpacing: 9,
      childAspectRatio: 0.98,
      children: [
        for (final key in ExpenseCategories.all)
          Builder(builder: (context) {
            final s = ExpenseCategories.style(key);
            final isSel = key == selected;
            return Semantics(
              selected: isSel,
              button: true,
              child: GestureDetector(
                onTap: () => onSelect(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSel ? s.tint(b) : c.field,
                    borderRadius: BorderRadius.circular(AppSizes.tileRadius),
                    border: Border.all(color: isSel ? s.color : Colors.transparent, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(s.icon, size: 22, color: s.color),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(s.name, style: AppText.smallStrong.copyWith(color: c.text, fontSize: 12.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _DateRow({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.tileRadius),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.tileRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(LucideIcons.calendar, size: 20, color: c.muted),
              const SizedBox(width: 14),
              Expanded(child: Text(text, style: AppText.body.copyWith(color: c.text, fontSize: 16))),
              Text('Change', style: AppText.body.copyWith(color: c.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
