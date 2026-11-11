import 'package:expenses_charts/pages/home_shell.dart';
import 'package:expenses_charts/providers/currency_provider.dart';
import 'package:expenses_charts/providers/expense_store.dart';
import 'package:expenses_charts/providers/settings.dart';
import 'package:expenses_charts/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SQLite through FFI on every platform (unchanged from earlier versions).
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final settings = SettingsProvider();
  final currencies = CurrencyProvider();
  final store = ExpenseStore();
  await Future.wait([settings.load(), currencies.load(), store.load()]);

  runApp(MyApp(settings: settings, currencies: currencies, store: store));
}

class MyApp extends StatelessWidget {
  final SettingsProvider settings;
  final CurrencyProvider currencies;
  final ExpenseStore store;

  const MyApp({super.key, required this.settings, required this.currencies, required this.store});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: currencies),
        ChangeNotifierProvider.value(value: store),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, s, _) => MaterialApp(
          title: 'Money Tracker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: s.themeMode,
          home: const HomeShell(),
        ),
      ),
    );
  }
}
