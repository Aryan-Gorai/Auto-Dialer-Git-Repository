import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Primary action button — solid purple background.
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;
  final double? height;

  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: height ?? 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDesignTokens.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppDesignTokens.neutral300,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize:
                    expanded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
    return expanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

/// Secondary button — outlined purple border.
class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final double? height;

  const AppSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: height ?? 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppDesignTokens.primary,
          side: BorderSide(color: AppDesignTokens.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
          ),
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
    return expanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

/// Text button — no background, purple text.
class AppTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  const AppTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color ?? AppDesignTokens.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Danger text button — red text, used for destructive actions.
class AppDangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const AppDangerButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      color: AppDesignTokens.danger,
    );
  }
}

/// Circular icon button with tinted background.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final String? tooltip;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 40,
    this.iconSize = 20,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppDesignTokens.primarySoft,
          shape: BoxShape.circle,
          boxShadow: AppDesignTokens.softShadow,
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: iconColor ?? AppDesignTokens.primary,
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}
