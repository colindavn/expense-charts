import 'dart:io';

import 'package:csv/csv.dart';
import 'package:expenses_charts/constants/categories.dart';
import 'package:expenses_charts/models/expenses.dart';
import 'package:expenses_charts/providers/currency_provider.dart';
import 'package:expenses_charts/providers/expense_store.dart';
import 'package:expenses_charts/providers/settings.dart';
import 'package:expenses_charts/theme/app_theme.dart';
import 'package:expenses_charts/theme/tokens.dart';
import 'package:expenses_charts/utils/database_helper.dart';
import 'package:expenses_charts/utils/dates.dart';
import 'package:expenses_charts/widgets/text_prompt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

/// CSV in the processing script's format:
/// Date,Intitulé,Montant,Type,Revenu/Dépense  (MM/dd/yyyy, French category, -1 expense / 1 income)
class CsvCodec {
  CsvCodec._();

  static const header = ['Date', 'Intitulé', 'Montant', 'Type', 'Revenu/Dépense'];
  static final _date = DateFormat('MM/dd/yyyy');

  static String encode(List<Expense> entries) {
    final rows = <List<dynamic>>[header];
    for (final e in entries) {
      rows.add([
        _date.format(e.start),
        e.label,
        e.value.toString(),
        e.isIncome ? '' : ExpenseCategories.getCsvName(e.category),
        e.isIncome ? '1' : '-1',
      ]);
    }
    return '${const ListToCsvConverter(eol: '\n').convert(rows)}\n';
  }

  /// Reads the script format, or the older raw-column format
  /// (millisSinceEpochStart, millisSinceEpochEnd, type, category, label, value).
  static List<Expense> decode(String content) {
    final text = content.replaceAll('\r\n', '\n').replaceFirst('﻿', '');
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(text)
        .where((r) => r.isNotEmpty && !(r.length == 1 && r.first.toString().trim().isEmpty))
        .toList();
    if (rows.isEmpty) return [];
    final keys = rows.first.map((k) => k.toString().trim()).toList();
    final body = rows.skip(1);

    Map<String, String> asMap(List<dynamic> r) =>
        {for (var j = 0; j < keys.length && j < r.length; j++) keys[j]: r[j].toString().trim()};

    if (keys.contains('millisSinceEpochStart')) {
      return body
          .map(asMap)
          .where((m) => m['type'] == 'expense' || m['type'] == 'income')
          .map((m) => Expense.fromMap(m))
          .toList();
    }
    if (!keys.contains('Date') || !keys.contains('Montant')) {
      throw const FormatException('Unknown CSV columns. Expected Date,Intitulé,Montant,Type,Revenu/Dépense.');
    }
    final out = <Expense>[];
    for (final r in body) {
      final m = asMap(r);
      final dateText = m['Date'] ?? '';
      if (dateText.isEmpty) continue;
      final day = Dates.atNoon(_date.parseStrict(dateText));
      final amount = double.parse((m['Montant'] ?? '0').replaceAll(',', '.')).abs();
      final income = (m['Revenu/Dépense'] ?? '-1').trim() == '1';
      final category = income ? 'income' : (ExpenseCategories.fromCsvName(m['Type'] ?? '') ?? 'exceptional');
      out.add(Expense(
        millisSinceEpochStart: day.millisecondsSinceEpoch,
        millisSinceEpochEnd: day.millisecondsSinceEpoch,
        type: income ? 'income' : 'expense',
        category: category,
        label: m['Intitulé'] ?? '',
        value: amount,
      ));
    }
    return out;
  }
}

/// UI flows behind the "Data" rows of the Budget screen.
class DataTransfer {
  DataTransfer._();

  static void _toast(ScaffoldMessengerState m, String text) => m.showSnackBar(SnackBar(content: Text(text)));

  static Future<String?> _askFilename(BuildContext context, String suggested, String ext) async {
    final c = AppColors.of(context);
    final name = await showTextPrompt<String>(
      context,
      title: 'File name',
      initial: suggested,
      parse: (text) {
        final v = text.trim();
        return v.isEmpty || v.contains('/') || v.contains('\\') ? null : v;
      },
      style: AppText.body.copyWith(color: c.text),
      suffixText: '.$ext',
    );
    if (name == null) return null;
    return name.endsWith('.$ext') ? name : '$name.$ext';
  }

  static String _stamp() => DateFormat('yyyy-MM-dd').format(Dates.now());

  /// Full copy of the SQLite file.
  static Future<void> backupDatabase(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null || !context.mounted) return;
      final name = await _askFilename(context, 'expenses_backup_${_stamp()}', 'db');
      if (name == null) return;
      await File(await DatabaseHelper.databasePath()).copy(p.join(dir, name));
      _toast(messenger, 'Database saved as $name');
    } catch (e) {
      _toast(messenger, 'Backup failed: $e');
    }
  }

  /// Imports a .db file, merging it or replacing every entry.
  static Future<void> importDatabase(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final store = context.read<ExpenseStore>();
    final currencies = context.read<CurrencyProvider>();
    final c = AppColors.of(context);

    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import database'),
        content: Text(
          'Merge adds the entries you don\'t have yet. Replace deletes your current entries first.',
          style: AppText.body.copyWith(color: c.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'replace'), child: Text('Replace', style: AppText.bodyStrong.copyWith(color: c.danger))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'merge'), child: const Text('Merge')),
        ],
      ),
    );
    if (mode == null) return;

    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.any);
      final path = picked?.files.single.path;
      if (path == null) return;

      final imported = await openReadOnlyDatabase(path);
      final List<Expense> rows;
      try {
        rows = (await imported.query('expenses')).map(Expense.fromMap).toList();
      } finally {
        await imported.close();
      }

      if (mode == 'replace') {
        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Replace all entries?'),
            content: Text(
              'Your ${store.entries.length} current entries will be deleted and replaced by ${rows.length} from the file. Back up first if unsure.',
              style: AppText.body.copyWith(color: c.muted),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Replace', style: AppText.bodyStrong.copyWith(color: c.danger))),
            ],
          ),
        );
        if (ok != true) return;
        final n = await DatabaseHelper().replaceEntries(rows);
        await store.load();
        await currencies.load();
        _toast(messenger, 'Database replaced ($n entries)');
      } else {
        final n = await DatabaseHelper().mergeEntries(rows);
        await store.load();
        _toast(messenger, 'Database merged ($n new entries)');
      }
    } catch (e) {
      _toast(messenger, 'Import failed: $e');
    }
  }

  /// Imports a CSV in the script format (or the old raw format), skipping duplicates.
  static Future<void> importCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final store = context.read<ExpenseStore>();
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.any);
      final path = picked?.files.single.path;
      if (path == null) return;
      final rows = CsvCodec.decode(await File(path).readAsString());
      final n = await DatabaseHelper().mergeEntries(rows);
      await store.load();
      _toast(messenger, 'CSV imported ($n new of ${rows.length} rows)');
    } catch (e) {
      _toast(messenger, 'CSV import failed: $e');
    }
  }

  /// Asks for a range, then writes the CSV.
  static Future<void> exportCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final store = context.read<ExpenseStore>();
    final settings = context.read<SettingsProvider>();
    final c = AppColors.of(context);
    final now = Dates.now();

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.card,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 18),
            Text('Export CSV', style: AppText.sectionTitle.copyWith(color: c.text)),
            const SizedBox(height: 6),
            for (final o in const [('month', 'This month'), ('year', 'This year'), ('all', 'Everything'), ('custom', 'Choose dates…')])
              ListTile(
                title: Text(o.$2, style: AppText.body.copyWith(color: c.text)),
                onTap: () => Navigator.pop(ctx, o.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    DateTime from, to;
    switch (choice) {
      case 'month':
        from = Dates.monthStart(now);
        to = Dates.monthEnd(now);
      case 'year':
        from = DateTime(now.year, 1, 1);
        to = DateTime(now.year, 12, 31);
      case 'all':
        from = DateTime(1970);
        to = DateTime(2200);
      default:
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          initialDateRange: DateTimeRange(start: Dates.monthStart(now), end: Dates.dateOnly(now)),
        );
        if (range == null) return;
        from = range.start;
        to = range.end;
    }

    try {
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null || !context.mounted) return;
      final name = await _askFilename(context, 'expenses_${_stamp()}', 'csv');
      if (name == null) return;
      final f = Dates.dateOnly(from), t = Dates.dateOnly(to);
      final rows = store.entries.where((e) {
        final d = Dates.dateOnly(e.start);
        return !d.isBefore(f) && !d.isAfter(t);
      }).toList()
        ..sort((a, b) => a.millisSinceEpochStart.compareTo(b.millisSinceEpochStart));
      await File(p.join(dir, name)).writeAsString(CsvCodec.encode(rows));
      settings.lastCsvExport = Dates.now();
      _toast(messenger, '${rows.length} entries exported to $name');
    } catch (e) {
      _toast(messenger, 'CSV export failed: $e');
    }
  }
}
