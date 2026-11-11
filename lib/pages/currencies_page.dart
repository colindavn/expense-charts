import 'package:expenses_charts/models/currency.dart';
import 'package:expenses_charts/providers/currency_provider.dart';
import 'package:expenses_charts/providers/expense_store.dart';
import 'package:expenses_charts/theme/app_theme.dart';
import 'package:expenses_charts/theme/tokens.dart';
import 'package:expenses_charts/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

/// Preferred currency + the list of available currencies with their rates.
class CurrenciesPage extends StatelessWidget {
  const CurrenciesPage({super.key});

  static String rate(double r) => r >= 100 ? r.toStringAsFixed(2) : (r >= 1 ? r.toStringAsFixed(4) : r.toStringAsFixed(6));

  Future<void> _setPreferred(BuildContext context, Currency next) async {
    final provider = context.read<CurrencyProvider>();
    final store = context.read<ExpenseStore>();
    final c = AppColors.of(context);
    if (next.code == provider.preferredCode) return;
    final old = provider.preferred;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Switch to ${next.code}?'),
        content: Text(
          'Rates will be recalculated against ${next.code}. Convert your existing amounts from '
          '${old.code} to ${next.code} at 1 ${old.symbol} = ${rate(next.rate)} ${next.symbol}?',
          style: AppText.body.copyWith(color: c.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: const Text('Keep amounts')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'convert'), child: const Text('Convert')),
        ],
      ),
    );
    if (choice == null) return;
    await provider.setPreferred(next.code, convertEntries: choice == 'convert');
    await store.load();
  }

  Future<void> _edit(BuildContext context, {Currency? existing}) async {
    final provider = context.read<CurrencyProvider>();
    final result = await showDialog<Currency>(
      context: context,
      builder: (_) => _CurrencyDialog(existing: existing, preferred: provider.preferred),
    );
    if (result != null) await provider.upsert(result);
  }

  Future<void> _remove(BuildContext context, Currency cur) async {
    final provider = context.read<CurrencyProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final error = await provider.remove(cur.code);
    messenger.showSnackBar(SnackBar(content: Text(error ?? '${cur.code} removed')));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final provider = context.watch<CurrencyProvider>();
    final preferred = provider.preferred;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeader(
            overline: 'Settings',
            title: 'Currencies',
            trailing: CircleIconButton(icon: LucideIcons.x, onTap: () => Navigator.pop(context), tooltip: 'Close'),
          ),
          const SectionLabel('Preferred currency'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: RadioGroup<String>(
                groupValue: provider.preferredCode,
                onChanged: (code) {
                  final cur = provider.byCode(code);
                  if (cur != null) _setPreferred(context, cur);
                },
                child: Column(
                  children: [
                    for (final cur in provider.currencies)
                      RadioListTile<String>(
                        value: cur.code,
                        activeColor: c.ink,
                        title: Text('${cur.code}  ${cur.symbol}', style: AppText.bodyStrong.copyWith(color: c.text)),
                        subtitle: Text('Used for new entries and every total', style: AppText.small.copyWith(color: c.muted)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SectionLabel('Available currencies'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Column(
                children: [
                  for (final cur in provider.currencies) ...[
                    InkWell(
                      onTap: () => _edit(context, existing: cur),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: c.field, borderRadius: BorderRadius.circular(12)),
                              child: Text(cur.symbol, style: AppText.tileAmount.copyWith(color: c.text, fontSize: 17)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cur.code, style: AppText.itemTitle.copyWith(color: c.text)),
                                  Text(
                                    cur.code == preferred.code
                                        ? 'Preferred'
                                        : '1 ${preferred.symbol} = ${rate(cur.rate)} ${cur.symbol}',
                                    style: AppText.itemSub.copyWith(color: c.muted),
                                  ),
                                ],
                              ),
                            ),
                            if (cur.code != preferred.code)
                              IconButton(
                                tooltip: 'Remove',
                                icon: Icon(LucideIcons.trash2, size: 18, color: c.muted),
                                onPressed: () => _remove(context, cur),
                              ),
                            Icon(LucideIcons.pencil, size: 16, color: c.faint),
                          ],
                        ),
                      ),
                    ),
                    const CardDivider(),
                  ],
                  InkWell(
                    onTap: () => _edit(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Icon(LucideIcons.plus, size: 20, color: c.text),
                          const SizedBox(width: 12),
                          Text('Add currency', style: AppText.bodyStrong.copyWith(color: c.text)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyDialog extends StatefulWidget {
  final Currency? existing;
  final Currency preferred;

  const _CurrencyDialog({this.existing, required this.preferred});

  @override
  State<_CurrencyDialog> createState() => _CurrencyDialogState();
}

class _CurrencyDialogState extends State<_CurrencyDialog> {
  late final _code = TextEditingController(text: widget.existing?.code ?? '');
  late final _symbol = TextEditingController(text: widget.existing?.symbol ?? '');
  late final _rate = TextEditingController(text: widget.existing == null ? '' : CurrenciesPage.rate(widget.existing!.rate));
  String? _error;

  bool get _isPreferred => widget.existing?.code == widget.preferred.code;

  @override
  void dispose() {
    _code.dispose();
    _symbol.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _code.text.trim().toUpperCase();
    final symbol = _symbol.text.trim().isEmpty ? code : _symbol.text.trim();
    final rate = _isPreferred ? 1.0 : double.tryParse(_rate.text.replaceAll(',', '.'));
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
      setState(() => _error = 'Use a 3-letter code, like USD');
      return;
    }
    if (rate == null || rate <= 0) {
      setState(() => _error = 'Enter a rate above 0');
      return;
    }
    Navigator.pop(context, Currency(code: code, symbol: symbol, rate: rate));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = AppText.body.copyWith(color: c.text, fontSize: 16);
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add currency' : 'Edit ${widget.existing!.code}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.existing == null) ...[
            TextField(
              controller: _code,
              autofocus: true,
              style: style,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(3)],
              decoration: const InputDecoration(labelText: 'Code', hintText: 'USD'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _symbol,
            style: style,
            decoration: const InputDecoration(labelText: 'Symbol', hintText: r'$'),
          ),
          if (!_isPreferred) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _rate,
              style: style,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Rate',
                prefixText: '1 ${widget.preferred.symbol} = ',
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: AppText.small.copyWith(color: c.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
