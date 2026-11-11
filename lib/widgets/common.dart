import 'package:expenses_charts/constants/categories.dart';
import 'package:expenses_charts/theme/app_theme.dart';
import 'package:expenses_charts/theme/tokens.dart';
import 'package:flutter/material.dart';

/// White rounded card without shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSizes.cardPadding),
    this.color,
    this.radius = AppSizes.cardRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.of(context).card,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Small muted overline + large Space Grotesk title.
class ScreenHeader extends StatelessWidget {
  final String overline;
  final String title;
  final Widget? trailing;

  const ScreenHeader({super.key, required this.overline, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSizes.gutter + 4, MediaQuery.paddingOf(context).top + 18, AppSizes.gutter, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(overline, style: AppText.overline.copyWith(color: c.muted)),
                const SizedBox(height: 4),
                Text(title, style: AppText.pageTitle.copyWith(color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// White circle with a hairline border, used for ‹ › and ✕.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool filled;
  final String? tooltip;

  const CircleIconButton({super.key, required this.icon, this.onTap, this.size = 44, this.filled = false, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final button = Material(
      color: filled ? c.field : c.card,
      shape: CircleBorder(side: filled ? BorderSide.none : BorderSide(color: c.divider)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: 20, color: onTap == null ? c.faint : c.text),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Small rounded pill button ("Edit budget", "Change", "Month").
class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final BorderSide? border;
  final EdgeInsetsGeometry padding;

  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.icon,
    this.border,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: StadiumBorder(side: border ?? BorderSide.none),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: foreground), const SizedBox(width: 8)],
              Text(label, style: AppText.bodyStrong.copyWith(color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grey track holding a selected pill.
/// [dark]: selected pill is near-black (Analytics). Otherwise white (New entry).
class PillSegmented<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final bool dark;
  final double height;

  const PillSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.dark = false,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.track, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == selected ? (dark ? c.ink : c.card) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: v == selected && !dark
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Text(
                    label(v),
                    style: AppText.bodyStrong.copyWith(
                      fontSize: 15.5,
                      color: v == selected ? (dark ? c.onInk : c.text) : c.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rounded square with the category tint and icon.
class CategoryIconBox extends StatelessWidget {
  final CategoryStyle style;
  final double size;

  const CategoryIconBox({super.key, required this.style, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.tint(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(style.icon, size: size * 0.5, color: style.color),
    );
  }
}

/// Lavender "Period" tag.
class PeriodTag extends StatelessWidget {
  const PeriodTag({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.periodBg, borderRadius: BorderRadius.circular(6)),
      child: Text('Period', style: AppText.smallStrong.copyWith(color: c.periodText, fontSize: 11.5)),
    );
  }
}

/// One row of a list: icon box, title + subtitle, amount on the right.
class EntryRow extends StatelessWidget {
  final CategoryStyle style;
  final String title;
  final String subtitle;
  final String amount;
  final bool income;
  final bool period;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;

  const EntryRow({
    super.key,
    required this.style,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.income,
    this.period = false,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.symmetric(vertical: 13),
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            CategoryIconBox(style: style),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title, style: AppText.itemTitle.copyWith(color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (period) ...[const SizedBox(width: 8), const PeriodTag()],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.itemSub.copyWith(color: c.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(amount, style: AppText.itemAmount.copyWith(color: income ? c.income : c.text)),
          ],
        ),
      ),
    );
  }
}

/// Uppercase muted section label ("CATEGORIES").
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.gutter + 4, 22, AppSizes.gutter, 10),
      child: Text(text.toUpperCase(), style: AppText.sectionLabel.copyWith(color: AppColors.of(context).muted)),
    );
  }
}

/// Card header: title on the left, optional link on the right.
class CardHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;

  const CardHeader({super.key, required this.title, this.action, this.onAction, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Expanded(child: Text(title, style: AppText.sectionTitle.copyWith(color: c.text))),
        if (trailing != null) trailing!,
        if (action != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(action!, style: AppText.link.copyWith(color: c.text)),
            ),
          ),
      ],
    );
  }
}

/// Full-width near-black button ("Save expense").
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const PrimaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.ink,
          foregroundColor: c.onInk,
          disabledBackgroundColor: c.ink.withValues(alpha: 0.35),
          disabledForegroundColor: c.onInk.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: AppText.button.copyWith(fontSize: 17),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Thin divider used inside cards.
class CardDivider extends StatelessWidget {
  final double indent;
  const CardDivider({super.key, this.indent = 0});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, indent: indent, color: AppColors.of(context).divider);
}
