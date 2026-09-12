import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../state/auth_provider.dart';

class AberturaScreen extends ConsumerStatefulWidget {
  const AberturaScreen({super.key});

  @override
  ConsumerState<AberturaScreen> createState() => _AberturaScreenState();
}

class _AberturaScreenState extends ConsumerState<AberturaScreen> {
  @override
  void initState() {
    super.initState();
    _decideNext();
  }

  Future<void> _decideNext() async {
    // Pequena pausa só para a animação do logo respirar — a decisão real
    // é o estado de sessão, não o tempo.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final user = ref.read(authServiceProvider).currentUser;
    context.go(user != null ? '/controlo' : '/boas-vindas');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpeedLockColors.bgApp,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', width: 160),
            const SizedBox(height: 24),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: SpeedLockColors.accent),
            ),
            const SizedBox(height: 14),
            const Text(
              'A preparar a tua experiência…',
              style: TextStyle(color: SpeedLockColors.text2, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
