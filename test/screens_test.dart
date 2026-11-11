// Renders every screen with the mockup's November 2026 sample data.
// Checks the key numbers; set SCREENSHOT_DIR to also save PNGs of each screen.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:expenses_charts/main.dart';
import 'package:expenses_charts/models/expenses.dart';
import 'package:expenses_charts/providers/currency_provider.dart';
import 'package:expenses_charts/providers/expense_store.dart';
import 'package:expenses_charts/providers/settings.dart';
import 'package:expenses_charts/utils/database_helper.dart';
import 'package:expenses_charts/utils/dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Expense _e(String label, String category, double value, int day, {int? endDay, int month = 11, String type = 'expense'}) {
  final s = DateTime(2026, month, day, 12);
  final e = DateTime(2026, month, endDay ?? day, 12);
  return Expense(
    millisSinceEpochStart: s.millisecondsSinceEpoch,
    millisSinceEpochEnd: e.millisecondsSinceEpoch,
    type: type,
    category: category,
    label: label,
    value: value,
  );
}

final _sample = [
  _e('Rent share', 'regular', 380.00, 1),
  _e('Phone', 'regular', 23.70, 3),
  _e('Streaming', 'regular', 8.60, 5),
  _e('Supermarket', 'grocery', 92.50, 1),
  _e('Market', 'grocery', 62.45, 2),
  _e('Groceries', 'grocery', 54.00, 6),
  _e('Groceries', 'grocery', 27.50, 10),
  _e('Hotel — Lyon', 'trip', 210.00, 7, endDay: 9),
  _e('Brunch', 'restaurant', 53.40, 1),
  _e('Lunch', 'restaurant', 52.00, 5),
  _e('Dinner out', 'restaurant', 42.80, 9),
  _e('Concert', 'leisure', 73.50, 1),
  _e('Cinema', 'leisure', 23.00, 8),
  _e('Doctor', 'health', 36.50, 2),
  _e('Pharmacy', 'health', 18.40, 9),
  _e('Gift', 'exceptional', 52.00, 1),
  _e('Wine', 'alcohol', 21.75, 7),
  _e('Drinks', 'alcohol', 16.50, 8),
  _e('Salary', 'income', 2450.00, 6, type: 'income'),
  _e('Groceries', 'grocery', 20.00, 28, month: 10),
  _e('Bakery', 'grocery', 8.00, 29, month: 10),
  _e('Groceries', 'grocery', 35.00, 30, month: 10),
  _e('Coffee', 'restaurant', 6.00, 31, month: 10),
];

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final a in assets) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }

  await load('Inter', [for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/Inter-$w.ttf']);
  await load('SpaceGrotesk', [for (final w in ['Regular', 'Medium', 'Bold']) 'assets/fonts/SpaceGrotesk-$w.ttf']);
  await load('packages/lucide_icons_flutter/Lucide', ['packages/lucide_icons_flutter/assets/lucide.ttf']);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final shotDir = Platform.environment['SCREENSHOT_DIR'];
  final boundaryKey = GlobalKey();
  late Directory tmp;
  late SettingsProvider settings;
  late CurrencyProvider currencies;
  late ExpenseStore store;

  setUp(() async {
    Dates.now = () => DateTime(2026, 11, 10, 15);
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('screens_test');
    DatabaseHelper.pathOverride = p.join(tmp.path, 'screens.db');
  });

  tearDown(() async {
    Dates.now = DateTime.now;
    await DatabaseHelper.close();
    DatabaseHelper.pathOverride = null;
    await tmp.delete(recursive: true);
  });

  Future<void> boot(WidgetTester tester, {ThemeMode theme = ThemeMode.light}) async {
    await tester.runAsync(() async {
      await _loadFonts();
      for (final e in _sample) {
        await DatabaseHelper().insertExpense(e);
      }
      settings = SettingsProvider();
      currencies = CurrencyProvider();
      store = ExpenseStore();
      await Future.wait([settings.load(), currencies.load(), store.load()]);
      settings.themeMode = theme;
    });
    tester.view.physicalSize = const Size(780, 2080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: MyApp(settings: settings, currencies: currencies, store: store),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    if (shotDir == null) return;
    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(p.join(shotDir, '$name.png')).writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Overview shows the budget figures', (tester) async {
    await boot(tester);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('€551.40'), findsOneWidget);
    expect(find.text('of €1,800.00 monthly budget · 20 days left'), findsOneWidget);
    expect(find.text('€1,248.60 spent · 69%'), findsOneWidget);
    expect(find.text('€27.57 / day'), findsOneWidget);
    expect(find.text('+€2,450.00'), findsOneWidget);
    expect(find.text('−€1,248.60'), findsOneWidget);
    expect(find.text('€1,248'), findsOneWidget);
    expect(find.text('4 others'), findsOneWidget);
    expect(find.text('Grocery · Today'), findsOneWidget);
    await shot(tester, '1_overview');
  });

  testWidgets('Analytics shows 14 days with average', (tester) async {
    await boot(tester);
    await tab(tester, 'Analytics');
    expect(find.text('Last 14 days'), findsOneWidget);
    expect(find.text('Tue 10 Nov'), findsOneWidget);
    expect(find.text('By category'), findsOneWidget);
    expect(find.text('€412.30'), findsOneWidget);
    await shot(tester, '2_analytics');
  });

  testWidgets('Activity groups entries by day', (tester) async {
    await boot(tester);
    await tab(tester, 'Activity');
    expect(find.text('Today · Tue 10 Nov'), findsOneWidget);
    expect(find.text('Hotel — Lyon'), findsOneWidget);
    expect(find.text('Trip · 7–9 Nov · 3 nights · €70.00/night'), findsOneWidget);
    expect(find.text('Period'), findsOneWidget);
    await shot(tester, '3_activity');

    final chip = find.byKey(const ValueKey('chip-Restaurant'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('Dinner out'), findsOneWidget);
    expect(find.text('Hotel — Lyon'), findsNothing);
  });

  testWidgets('New entry form computes the per-day amount', (tester) async {
    await boot(tester);
    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();
    expect(find.text('New entry'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '42.80');
    await tester.enterText(find.byType(TextField).at(1), 'Dinner out');
    await tester.tap(find.text('Restaurant').last);
    await tester.pumpAndSettle();
    expect(find.text('Today · Tue 10 Nov'), findsWidgets);
    await shot(tester, '4_new_entry');

    await tester.tap(find.text('Over a period'));
    await tester.pumpAndSettle();
    expect(find.text('3 days → €14.27/day'), findsOneWidget);
    await shot(tester, '4b_new_entry_period');
  });

  testWidgets('Budget & data lists the settings', (tester) async {
    await boot(tester);
    await tab(tester, 'Budget');
    expect(find.text('€1,800.00'), findsOneWidget);
    expect(find.text('Alert at 80% spent'), findsOneWidget);
    expect(find.text('EUR €'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    await shot(tester, '5_budget');

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('€2,000.00'), findsOneWidget);
    expect(settings.monthlyBudget, 2000);
  });

  testWidgets('Dark theme renders', (tester) async {
    await boot(tester, theme: ThemeMode.dark);
    expect(find.text('€551.40'), findsOneWidget);
    await shot(tester, '6_overview_dark');
  });
}
