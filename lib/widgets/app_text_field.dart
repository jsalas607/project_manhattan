import 'package:flutter/material.dart';

import '../core/app_design_system.dart';

/// Campo de texto reutilizable con el estilo del sistema.
/// Con [isPassword: true] muestra un ojito para revelar/ocultar la contraseña.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.isPassword = false,
    this.hintText,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final bool isPassword;
  final String? hintText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final effectiveObscure = widget.isPassword ? !_showPassword : widget.obscureText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTypography.labelLarge),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: effectiveObscure,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          style: AppTypography.bodyLarge,
          cursorColor: AppColors.naranjaAccion,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textoClaroMedio.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textoClaroMedio,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.naranjaAccion,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
