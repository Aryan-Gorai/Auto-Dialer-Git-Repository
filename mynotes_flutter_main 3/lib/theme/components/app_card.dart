import 'package:flutter/material.dart';
import '../app_theme.dart';

/// A styled card container with shadow, border, and consistent padding.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadow;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.shadow,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null
            ? (backgroundColor ?? AppDesignTokens.surface)
            : null,
        gradient: gradient,
        borderRadius:
            BorderRadius.circular(borderRadius ?? AppDesignTokens.radiusMd),
        border: Border.all(
          color: borderColor ?? AppDesignTokens.neutral200,
          width: borderWidth,
        ),
        boxShadow: shadow ?? AppDesignTokens.cardShadow,
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(borderRadius ?? AppDesignTokens.radiusMd),
        child: Padding(
          padding: padding ??
              EdgeInsets.all(AppDesignTokens.spacingMd),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }
    return card;
  }
}

/// Card with a colored left accent border.
class AppAccentCard extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const AppAccentCard({
    super.key,
    required this.child,
    required this.accentColor,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: margin,
      padding: EdgeInsets.zero,
      borderColor: AppDesignTokens.neutral200,
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppDesignTokens.radiusMd),
                  bottomLeft: Radius.circular(AppDesignTokens.radiusMd),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: padding ??
                    EdgeInsets.all(AppDesignTokens.spacingMd),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
