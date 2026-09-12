import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Marcador de posição para ecrãs ainda não portados do mockup HTML
/// (`design/speedlock-screens.html`) para Flutter. Cada ecrã real deve
/// substituir o body do seu `Scaffold` por isto — a rota e o nome da
/// classe já ficam corretos, só falta o layout.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpeedLockColors.bgApp,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
