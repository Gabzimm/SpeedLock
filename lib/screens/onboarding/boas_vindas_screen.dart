import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../state/auth_provider.dart';

class BoasVindasScreen extends ConsumerWidget {
  const BoasVindasScreen({super.key});

  void _emBreve(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Login com Google — em breve.')),
    );
  }

  Future<void> _continuarSemLogin(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpeedLockColors.surface1,
        title: const Text('Continuar sem login', style: TextStyle(color: SpeedLockColors.text1)),
        content: const Text(
          'Sem sessão, a trotinete que ligares não fica registada à tua '
          'conta — não vais poder recuperar o acesso, autorizar outras '
          'pessoas, nem usar o "Reportar como roubada" para essa trotinete. '
          'Como convidado só podes alterar o limite de velocidade; '
          'bloquear, luzes e buzina exigem login.',
          style: TextStyle(color: SpeedLockColors.text2, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: SpeedLockColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar assim', style: TextStyle(color: SpeedLockColors.accent)),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    try {
      await ref.read(authServiceProvider).signInAsGuest();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível continuar como convidado. Tenta novamente.')),
        );
      }
      return;
    }
    if (context.mounted) context.push('/ligar');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: SpeedLockColors.bgApp,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              Image.asset('assets/logo.png', width: 170),
              const SizedBox(height: 24),
              // Anel decorativo + ícone, substitui a ilustração 3D do mockup.
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: SpeedLockColors.lineAccent, width: 1.5),
                      ),
                    ),
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: SpeedLockColors.lineAccent),
                      ),
                    ),
                    Container(
                      width: 66,
                      height: 66,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: SpeedLockColors.surface1,
                      ),
                      child: const Icon(Icons.electric_scooter, color: SpeedLockColors.accent, size: 32),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Bem-vindo!', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text(
                'Faça login para continuar',
                style: TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
              ),
              const SizedBox(height: 24),
              _ChoiceButton(
                icon: Icons.mail_outline,
                label: 'Login com E-mail',
                onTap: () => context.push('/login'),
              ),
              const SizedBox(height: 10),
              _ChoiceButton(
                icon: Icons.g_mobiledata,
                label: 'Login com Google',
                onTap: () => _emBreve(context),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _continuarSemLogin(context, ref),
                child: const Text(
                  'Continuar sem login',
                  style: TextStyle(
                    color: SpeedLockColors.text2,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: SpeedLockColors.lineAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SpeedLockColors.surface1,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SpeedLockColors.lineAccent),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: SpeedLockColors.text1),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: SpeedLockColors.text1,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: SpeedLockColors.text2, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
