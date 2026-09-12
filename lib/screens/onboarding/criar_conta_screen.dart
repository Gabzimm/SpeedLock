import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../services/api_client.dart';
import '../../state/auth_provider.dart';
import '../widgets/speedlock_primary_button.dart';
import '../widgets/speedlock_text_field.dart';

class CriarContaScreen extends ConsumerStatefulWidget {
  const CriarContaScreen({super.key});

  @override
  ConsumerState<CriarContaScreen> createState() => _CriarContaScreenState();
}

class _CriarContaScreenState extends ConsumerState<CriarContaScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text != _confirmPassword.text) {
      _showError('As senhas não coincidem.');
      return;
    }
    if (_password.text.length < 8) {
      _showError('A senha precisa de pelo menos 8 caracteres.');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).register(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
      // Sucesso: authStateProvider muda e o router avança para /controlo.
    } on fb.FirebaseAuthException catch (e) {
      _showError(_linkErrorMessage(e));
    } on ApiException catch (e) {
      _showError(_registerErrorMessage(e));
    } catch (e) {
      _showError('Não foi possível criar a conta. Tenta novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Ocorre quando quem estava como convidado (sessão anónima) cria conta
  // agora — ver AuthService.register, que faz linkWithCredential em vez
  // de registerUser para não perder a trotinete já ligada.
  String _linkErrorMessage(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
      case 'credential-already-in-use':
        return 'Já existe uma conta com este email.';
      case 'weak-password':
        return 'A senha precisa de pelo menos 8 caracteres.';
      case 'invalid-email':
        return 'Email inválido.';
      default:
        return 'Não foi possível criar a conta. Tenta novamente.';
    }
  }

  String _registerErrorMessage(ApiException e) {
    switch (e.code) {
      case 'already-exists':
        return 'Já existe uma conta com este email.';
      case 'resource-exhausted':
        return 'Demasiadas tentativas. Tenta mais tarde.';
      case 'invalid-argument':
        return 'Verifica o email e a senha (mínimo 8 caracteres).';
      default:
        return 'Não foi possível criar a conta. Tenta novamente.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpeedLockColors.bgApp,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Image.asset('assets/logo.png', width: 100)),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Text('Criar conta', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    const Text(
                      'Preenche os dados para começares.',
                      style: TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SpeedLockTextField(
                label: 'Nome',
                controller: _name,
                hint: 'O teu nome',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              SpeedLockTextField(
                label: 'Email',
                controller: _email,
                hint: 'nome@email.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline,
              ),
              const SizedBox(height: 12),
              SpeedLockTextField(
                label: 'Senha',
                controller: _password,
                hint: 'Mínimo 8 caracteres',
                obscurable: true,
                prefixIcon: Icons.lock_outline,
              ),
              const SizedBox(height: 12),
              SpeedLockTextField(
                label: 'Confirmar senha',
                controller: _confirmPassword,
                hint: 'Repete a senha',
                obscurable: true,
                prefixIcon: Icons.lock_outline,
              ),
              const SizedBox(height: 20),
              SpeedLockPrimaryButton(label: 'Criar conta', onPressed: _submit, loading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}
