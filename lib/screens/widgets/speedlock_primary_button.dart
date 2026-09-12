import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Botão com o gradiente roxo (`linear-gradient(90deg,#A855F7,#6D28D9)`
/// no CSS). Mostra um spinner em vez do texto quando `loading` é true —
/// os ecrãs de auth usam isto enquanto esperam a Cloud Function.
class SpeedLockPrimaryButton extends StatelessWidget {
  const SpeedLockPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: SpeedLockColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: loading ? null : onPressed,
          child: SizedBox(
            height: 48,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
