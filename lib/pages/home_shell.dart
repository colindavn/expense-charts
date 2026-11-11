import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:expenses_charts/pages/activity_page.dart';
import 'package:expenses_charts/pages/analytics_page.dart';
import 'package:expenses_charts/pages/budget_page.dart';
import 'package:expenses_charts/pages/entry_sheet.dart';
import 'package:expenses_charts/pages/overview_page.dart';
import 'package:expenses_charts/widgets/app_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// The four tabs and the bottom bar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _requestStorageIfNeeded();
  }

  /// Android 12 and older need storage access for import/export.
  Future<void> _requestStorageIfNeeded() async {
    try {
      if (!Platform.isAndroid) return;
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt < 33) await Permission.storage.request();
    } catch (e) {
      debugPrint('Storage permission request failed: $e');
    }
  }

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          OverviewPage(onOpenAnalytics: () => _go(1), onOpenActivity: () => _go(2)),
          const AnalyticsPage(),
          const ActivityPage(),
          const BudgetPage(),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        index: _index,
        onTab: _go,
        onAdd: () => openEntrySheet(context),
      ),
    );
  }
}
