import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../state/auth_provider.dart';
import '../widgets/six_digit_code_input.dart';
import '../widgets/speedlock_primary_button.dart';
import '../widgets/speedlock_text_field.dart';

enum _RecoverStep { email, code, newPassword }

class RecuperarSenhaScreen extends ConsumerStatefulWidget {
  const RecuperarSenhaScreen({super.key});

  @override
  ConsumerState<RecuperarSenhaScreen> createState() => _RecuperarSenhaScreenState();
}

class _RecuperarSenhaScreenState extends ConsumerState<RecuperarSenhaScreen> {
  final _email = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  _RecoverStep _step = _RecoverStep.email;
  String? _code;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendCode() async {
    if (_email.text.trim().isEmpty) {
      _showError('Insere o teu email.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).requestPasswordReset(_email.text.trim());
      if (mounted) setState(() => _step = _RecoverStep.code);
    } catch (e) {
      _showError('Não foi possível enviar o código. Tenta novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // O código só é validado a sério no passo 3 (confirmPasswordReset faz
  // as duas coisas juntas no backend) — aqui só o guardamos.
  void _onCodeEntered(String code) {
    setState(() {
      _code = code;
      _step = _RecoverStep.newPassword;
    });
  }

  Future<void> _saveNewPassword() async {
    final code = _code;
    if (code == null) return;
    if (_newPassword.text != _confirmPassword.text) {
      _showError('As senhas não coincidem.');
      return;
    }
    if (_newPassword.text.length < 8) {
      _showError('A senha precisa de pelo menos 8 caracteres.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).confirmPasswordReset(
            email: _email.text.trim(),
            code: code,
            newPassword: _newPassword.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha alterada. Já podes entrar.')),
        );
        context.go('/login');
      }
    } catch (e) {
      _showError('Código incorreto ou expirado. Volta a pedir um novo.');
      if (mounted) setState(() => _step = _RecoverStep.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _stepIndex => _RecoverStep.values.indexOf(_step);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpeedLockColors.bgApp,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepDots(current: _stepIndex),
              const SizedBox(height: 20),
              Expanded(
                child: switch (_step) {
                  _RecoverStep.email => _buildEmailStep(context),
                  _RecoverStep.code => _buildCodeStep(context),
                  _RecoverStep.newPassword => _buildPasswordStep(context),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_outline, color: SpeedLockColors.accent, size: 36),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Text('Recuperar senha', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              const Text(
                'Insere o teu email para receberes um código de verificação.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SpeedLockTextField(label: 'Email', controller: _email, hint: 'nome@email.com'),
        const Spacer(),
        SpeedLockPrimaryButton(label: 'Enviar código', onPressed: _sendCode, loading: _loading),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Voltar ao login', style: TextStyle(color: SpeedLockColors.text2)),
        ),
      ],
    );
  }

  Widget _buildCodeStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: SpeedLockColors.text1),
              onPressed: () => setState(() => _step = _RecoverStep.email),
            ),
          ],
        ),
        Center(
          child: Column(
            children: [
              Text('Verifica o teu email', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Enviámos um código de 6 dígitos para\n${_email.text}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SixDigitCodeInput(onCompleted: _onCodeEntered),
        const Spacer(),
        TextButton(
          onPressed: _loading ? null : _sendCode,
          child: const Text('Reenviar código', style: TextStyle(color: SpeedLockColors.accent)),
        ),
      ],
    );
  }

  Widget _buildPasswordStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: SpeedLockColors.text1),
              onPressed: () => setState(() => _step = _RecoverStep.code),
            ),
          ],
        ),
        Center(
          child: Column(
            children: [
              Text('Nova senha', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              const Text(
                'Cria uma nova senha para a tua conta.',
                style: TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SpeedLockTextField(
          label: 'Nova senha',
          controller: _newPassword,
          hint: 'Mínimo 8 caracteres',
          obscurable: true,
        ),
        const SizedBox(height: 12),
        SpeedLockTextField(
          label: 'Confirmar senha',
          controller: _confirmPassword,
          hint: 'Repete a senha',
          obscurable: true,
        ),
        const Spacer(),
        SpeedLockPrimaryButton(label: 'Guardar senha', onPressed: _saveNewPassword, loading: _loading),
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final on = i <= current;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? SpeedLockColors.accent : SpeedLockColors.line,
          ),
        );
      }),
    );
  }
}
