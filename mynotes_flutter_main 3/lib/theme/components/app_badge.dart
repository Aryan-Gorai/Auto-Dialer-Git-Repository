import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Color‑coded pill badge.
class AppBadge extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double? fontSize;

  const AppBadge({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.fontSize,
  });

  // ── Factory constructors for common semantic variants ──────────────

  factory AppBadge.success(String label, {IconData? icon}) => AppBadge(
        label: label,
        backgroundColor: AppDesignTokens.successSoft,
        textColor: AppDesignTokens.successDark,
        icon: icon,
      );

  factory AppBadge.danger(String label, {IconData? icon}) => AppBadge(
        label: label,
        backgroundColor: AppDesignTokens.dangerSoft,
        textColor: AppDesignTokens.danger,
        icon: icon,
      );

  factory AppBadge.warning(String label, {IconData? icon}) => AppBadge(
        label: label,
        backgroundColor: AppDesignTokens.warningSoft,
        textColor: AppDesignTokens.warningDark,
        icon: icon,
      );

  factory AppBadge.primary(String label, {IconData? icon}) => AppBadge(
        label: label,
        backgroundColor: AppDesignTokens.primarySoft,
        textColor: AppDesignTokens.primary,
        icon: icon,
      );

  factory AppBadge.info(String label, {IconData? icon}) => AppBadge(
        label: label,
        backgroundColor: AppDesignTokens.accentBlueSoft,
        textColor: AppDesignTokens.accentBlue,
        icon: icon,
      );

  factory AppBadge.neutral(String label, {IconData? icon}) => AppBadge(
        label: label,
        backgroundColor: AppDesignTokens.neutral100,
        textColor: AppDesignTokens.neutral700,
        icon: icon,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppDesignTokens.primarySoft,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor ?? AppDesignTokens.primary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize ?? 12,
              fontWeight: FontWeight.w600,
              color: textColor ?? AppDesignTokens.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Large metric tile with tinted background, icon, value, and label.
class AppMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final String? subtitle;

  const AppMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.backgroundColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDesignTokens.spacingMd),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
        border: Border.all(color: color.withOpacity(0.20)),
        boxShadow: AppDesignTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppDesignTokens.neutral700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.neutral500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Section header: optional icon + title + optional subtitle.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? AppDesignTokens.primary,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.neutral900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 14,
                color: AppDesignTokens.neutral600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thin horizontal progress bar.
class AppProgressBar extends StatelessWidget {
  final double value; // 0.0 – 1.0
  final Color? color;
  final Color? trackColor;
  final double height;

  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.trackColor,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: trackColor ?? AppDesignTokens.neutral200,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppDesignTokens.primary,
        ),
      ),
    );
  }
}
