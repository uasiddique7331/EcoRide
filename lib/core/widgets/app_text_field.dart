import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Consistent text input used across forms.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.validator,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.obscure = false,
    this.suffix,
    this.maxLength,
    this.inputFormatters,
    this.autofillHints,
    this.onFieldSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool obscure;
  final Widget? suffix;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final TextCapitalization textCapitalization;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscure,
      maxLength: maxLength,
      enabled: enabled,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixIcon: suffix,
        counterText: '',
      ),
    );
  }
}

/// Password input with show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      icon: Icons.lock_outline_rounded,
      obscure: _hidden,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      autofillHints: const [AutofillHints.password],
      suffix: IconButton(
        icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        onPressed: () => setState(() => _hidden = !_hidden),
      ),
    );
  }
}
