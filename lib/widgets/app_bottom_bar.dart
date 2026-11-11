import 'package:expenses_charts/theme/app_theme.dart';
import 'package:expenses_charts/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Bottom bar: 4 tabs with the black "+" button in the middle.
class AppBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onAdd;

  const AppBottomBar({super.key, required this.index, required this.onTab, required this.onAdd});

  static const _items = [
    (LucideIcons.house, 'Overview'),
    (LucideIcons.chartNoAxesColumn, 'Analytics'),
    (LucideIcons.list, 'Activity'),
    (LucideIcons.slidersHorizontal, 'Budget'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget tab(int i) {
      final selected = i == index;
      final color = selected ? c.text : c.muted;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          label: _items[i].$2,
          child: InkResponse(
            onTap: () => onTab(i),
            radius: 36,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_items[i].$1, size: 24, color: color),
                const SizedBox(height: 5),
                Text(
                  _items[i].$2,
                  style: AppText.navLabel.copyWith(color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              tab(0),
              tab(1),
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: 'Add entry',
                    child: Material(
                      color: c.ink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: onAdd,
                        child: SizedBox(width: 56, height: 56, child: Icon(LucideIcons.plus, size: 28, color: c.onInk)),
                      ),
                    ),
                  ),
                ),
              ),
              tab(2),
              tab(3),
            ],
          ),
        ),
      ),
    );
  }
}
