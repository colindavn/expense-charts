import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Fixed look of one category, used the same way on every screen.
class CategoryStyle {
  final String key;
  final String name;
  final Color color;
  final IconData icon;

  const CategoryStyle(this.key, this.name, this.color, this.icon);

  /// Soft background behind the icon.
  Color tint(Brightness b) => color.withValues(alpha: b == Brightness.dark ? 0.22 : 0.12);
}

class ExpenseCategories {
  ExpenseCategories._();

  /// Order used in the category grid and the filter chips.
  static const List<String> all = [
    'grocery',
    'restaurant',
    'regular',
    'trip',
    'leisure',
    'health',
    'alcohol',
    'exceptional',
  ];

  static const Map<String, CategoryStyle> styles = {
    'grocery': CategoryStyle('grocery', 'Grocery', Color(0xFF2F855A), LucideIcons.shoppingCart),
    'restaurant': CategoryStyle('restaurant', 'Restaurant', Color(0xFFDD6B20), LucideIcons.utensils),
    'regular': CategoryStyle('regular', 'Regular', Color(0xFF2B6CB0), LucideIcons.repeat),
    'trip': CategoryStyle('trip', 'Trip', Color(0xFF6B46C1), LucideIcons.briefcase),
    'leisure': CategoryStyle('leisure', 'Leisure', Color(0xFFC53074), LucideIcons.ticket),
    'health': CategoryStyle('health', 'Health', Color(0xFF0F8C8C), LucideIcons.heart),
    'alcohol': CategoryStyle('alcohol', 'Alcohol', Color(0xFFB7791F), LucideIcons.wine),
    'exceptional': CategoryStyle('exceptional', 'Exceptional', Color(0xFF4A5568), LucideIcons.star),
  };

  static const CategoryStyle income =
      CategoryStyle('income', 'Income', Color(0xFF1E8A5A), LucideIcons.arrowUpRight);

  static const CategoryStyle unknown =
      CategoryStyle('unknown', 'Other', Color(0xFF9AA0AA), LucideIcons.ellipsis);

  /// Category names used by the CSV export and the Python processing script.
  static const Map<String, String> csvNames = {
    'alcohol': 'Alcool',
    'exceptional': 'Exceptionnelle',
    'grocery': 'Course',
    'health': 'Santé',
    'leisure': 'Plaisir',
    'regular': 'Régulier',
    'restaurant': 'Restaurant',
    'trip': 'Voyage',
  };

  static bool isValid(String category) => all.contains(category);

  static CategoryStyle style(String category) => styles[category] ?? unknown;

  /// Style for an entry: incomes always use the green income look.
  static CategoryStyle styleFor(String type, String category) =>
      type == 'income' ? income : style(category);

  static String getDisplayName(String category) => styles[category]?.name ?? category;

  static String getCsvName(String category) => csvNames[category] ?? category;

  /// Reverse of [getCsvName]. Also accepts the internal key or display name.
  static String? fromCsvName(String name) {
    final n = name.trim().toLowerCase();
    for (final e in csvNames.entries) {
      if (e.value.toLowerCase() == n) return e.key;
    }
    for (final e in styles.entries) {
      if (e.key == n || e.value.name.toLowerCase() == n) return e.key;
    }
    return null;
  }
}
