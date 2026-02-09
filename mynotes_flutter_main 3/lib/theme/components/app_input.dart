import 'package:flutter/material.dart';
import '../app_theme.dart';

/// A styled text field matching the enterprise design system.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;
  final bool readOnly;
  final bool enabled;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry? contentPadding;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.readOnly = false,
    this.enabled = true,
    this.focusNode,
    this.contentPadding,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppDesignTokens.neutral700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          maxLines: maxLines,
          readOnly: readOnly,
          enabled: enabled,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppDesignTokens.neutral900,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20, color: AppDesignTokens.neutral500)
                : null,
            suffixIcon: suffixIcon,
            contentPadding: contentPadding,
          ),
        ),
      ],
    );
  }
}
