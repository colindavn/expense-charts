import 'package:expenses_charts/constants/categories.dart';
import 'package:expenses_charts/pages/currencies_page.dart';
import 'package:expenses_charts/providers/currency_provider.dart';
import 'package:expenses_charts/providers/settings.dart';
import 'package:expenses_charts/services/data_transfer.dart';
import 'package:expenses_charts/theme/app_theme.dart';
import 'package:expenses_charts/theme/tokens.dart';
import 'package:expenses_charts/utils/format.dart';
import 'package:expenses_charts/widgets/common.dart';
import 'package:expenses_charts/widgets/text_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

/// Dialog to change the monthly budget.
Future<void> editBudget(BuildContext context) async {
  final settings = context.read<SettingsProvider>();
  final currency = context.read<CurrencyProvider>().preferred;
  final c = AppColors.of(context);
  final value = await showTextPrompt<double>(
    context,
    title: 'Monthly budget',
    initial: Money.plain(settings.monthlyBudget),
    parse: (text) {
      final v = double.tryParse(text.replaceAll(',', '.'));
      return v != null && v >= 0 ? v : null;
    },
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    style: AppText.tileAmount.copyWith(color: c.text),
    prefixText: '${currency.symbol} ',
  );
  if (value != null) settings.monthlyBudget = value;
}

class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key});

  static const _weekDays = {DateTime.monday: 'Monday', DateTime.sunday: 'Sunday', DateTime.saturday: 'Saturday'};
  static const _themes = {ThemeMode.system: 'System', ThemeMode.light: 'Light', ThemeMode.dark: 'Dark'};

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final settings = context.watch<SettingsProvider>();
    final currencies = context.watch<CurrencyProvider>();
    final money = currencies.money;
    final last = settings.lastCsvExport;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const ScreenHeader(overline: 'Budget & data', title: 'Settings'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monthly budget', style: AppText.body.copyWith(color: c.muted)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(money.fmt(settings.monthlyBudget), style: AppText.bigAmount.copyWith(color: c.text)),
                          ),
                        ],
                      ),
                    ),
                    PillButton(
                      label: 'Change',
                      onTap: () => editBudget(context),
                      background: c.ink,
                      foreground: c.onInk,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const CardDivider(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Alert at 80% spent', style: AppText.body.copyWith(color: c.text, fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text('Notify when the remaining budget runs low', style: AppText.itemSub.copyWith(color: c.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(value: settings.alertAt80, onChanged: (v) => settings.alertAt80 = v),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SectionLabel('Categories'),
        _Group(children: [
          _Row(
            icon: LucideIcons.tag,
            title: 'Manage categories',
            subtitle: 'Colors, icons, per-category limits',
            value: '${ExpenseCategories.all.length}',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _CategoriesPage())),
          ),
        ]),
        const SectionLabel('Data'),
        _Group(children: [
          _Row(
            icon: LucideIcons.arrowUpToLine,
            title: 'Import CSV',
            subtitle: 'Same columns as your processing script',
            onTap: () => DataTransfer.importCsv(context),
          ),
          _Row(
            icon: LucideIcons.database,
            title: 'Import database',
            subtitle: 'Replace or merge a .db file',
            onTap: () => DataTransfer.importDatabase(context),
          ),
          _Row(
            icon: LucideIcons.arrowDownToLine,
            title: 'Export CSV',
            subtitle: last == null ? 'Never exported' : 'Last export · ${DateFormat('d MMM yyyy', 'en_US').format(last)}',
            onTap: () => DataTransfer.exportCsv(context),
          ),
          _Row(
            icon: LucideIcons.database,
            title: 'Back up database',
            subtitle: 'Full SQLite copy for safekeeping',
            onTap: () => DataTransfer.backupDatabase(context),
          ),
        ]),
        const SectionLabel('Preferences'),
        _Group(children: [
          _Row(
            icon: LucideIcons.circleEuro,
            title: 'Currency',
            value: '${currencies.preferred.code} ${currencies.preferred.symbol}',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CurrenciesPage())),
          ),
          _Row(
            icon: LucideIcons.calendar,
            title: 'Week starts on',
            value: _weekDays[settings.weekStartsOn] ?? 'Monday',
            onTap: () async {
              final v = await pickOption<int>(context, 'Week starts on', _weekDays, settings.weekStartsOn);
              if (v != null) settings.weekStartsOn = v;
            },
          ),
          _Row(
            icon: LucideIcons.moon,
            title: 'Appearance',
            value: _themes[settings.themeMode]!,
            onTap: () async {
              final v = await pickOption<ThemeMode>(context, 'Appearance', _themes, settings.themeMode);
              if (v != null) settings.themeMode = v;
            },
          ),
        ]),
      ],
    );
  }
}

/// Bottom sheet listing [options] with a check on [current].
Future<T?> pickOption<T>(BuildContext context, String title, Map<T, String> options, T current) {
  final c = AppColors.of(context);
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: c.card,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 18),
          Text(title, style: AppText.sectionTitle.copyWith(color: c.text)),
          const SizedBox(height: 6),
          for (final o in options.entries)
            ListTile(
              title: Text(o.value, style: AppText.body.copyWith(color: c.text)),
              trailing: o.key == current ? Icon(LucideIcons.check, size: 20, color: c.text) : null,
              onTap: () => Navigator.pop(ctx, o.key),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: AppColors.of(context).card, borderRadius: BorderRadius.circular(AppSizes.cardRadius)),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: CardDivider()),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback onTap;

  const _Row({required this.icon, required this.title, this.subtitle, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.field, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 19, color: c.text),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body.copyWith(color: c.text, fontSize: 16, fontWeight: FontWeight.w500)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppText.itemSub.copyWith(color: c.muted, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(value!, style: AppText.body.copyWith(color: c.muted)),
            ],
            const SizedBox(width: 10),
            Icon(LucideIcons.chevronRight, size: 18, color: c.faint),
          ],
        ),
      ),
    );
  }
}

/// Read-only list of the categories with their color and icon.
class _CategoriesPage extends StatelessWidget {
  const _CategoriesPage();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeader(
            overline: 'Settings',
            title: 'Categories',
            trailing: CircleIconButton(icon: LucideIcons.x, onTap: () => Navigator.pop(context), tooltip: 'Close'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < ExpenseCategories.all.length; i++) ...[
                    if (i > 0) const CardDivider(),
                    Builder(builder: (context) {
                      final s = ExpenseCategories.style(ExpenseCategories.all[i]);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            CategoryIconBox(style: s),
                            const SizedBox(width: 14),
                            Expanded(child: Text(s.name, style: AppText.itemTitle.copyWith(color: c.text))),
                            Text('CSV: ${ExpenseCategories.getCsvName(s.key)}', style: AppText.itemSub.copyWith(color: c.muted)),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.gutter + 4, 14, AppSizes.gutter + 4, 0),
            child: Text(
              'Editing categories and per-category limits is coming later.',
              style: AppText.small.copyWith(color: c.muted),
            ),
          ),
        ],
      ),
    );
  }
}
