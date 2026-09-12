import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Campo com label por cima, tal como `.field label` + `.field-input` no
/// mockup. `obscurable: true` acrescenta o botão de olho para senhas.
class SpeedLockTextField extends StatefulWidget {
  const SpeedLockTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscurable = false,
    this.keyboardType,
    this.prefixIcon,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscurable;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;

  @override
  State<SpeedLockTextField> createState() => _SpeedLockTextFieldState();
}

class _SpeedLockTextFieldState extends State<SpeedLockTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12.5,
            color: SpeedLockColors.text2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: widget.obscurable && _obscured,
          keyboardType: widget.keyboardType,
          style: const TextStyle(color: SpeedLockColors.text1, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: SpeedLockColors.text2),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, size: 18, color: SpeedLockColors.text2)
                : null,
            suffixIcon: widget.obscurable
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                      color: SpeedLockColors.text2,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
