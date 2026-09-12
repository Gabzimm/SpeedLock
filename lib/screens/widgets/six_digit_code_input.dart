import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';

/// As 6 caixas de código do mockup (`.code-box`), com avanço automático
/// para a caixa seguinte. `onCompleted` dispara assim que as 6 posições
/// estão preenchidas — quem usa isto não precisa de ler os controllers
/// manualmente.
class SixDigitCodeInput extends StatefulWidget {
  const SixDigitCodeInput({super.key, required this.onCompleted});

  final ValueChanged<String> onCompleted;

  @override
  State<SixDigitCodeInput> createState() => _SixDigitCodeInputState();
}

class _SixDigitCodeInputState extends State<SixDigitCodeInput> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    final code = _controllers.map((c) => c.text).join();
    if (code.length == 6) {
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        return SizedBox(
          width: 42,
          height: 46,
          child: TextField(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 17,
              color: SpeedLockColors.text1,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(counterText: ''),
            onChanged: (v) => _onChanged(i, v),
          ),
        );
      }),
    );
  }
}
