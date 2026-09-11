import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../services/auth_service.dart';
import '../../state/auth_provider.dart';
import '../widgets/six_digit_code_input.dart';
import '../widgets/speedlock_primary_button.dart';
import '../widgets/speedlock_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

/// 'form' é o email/senha normal; 'verify' aparece só quando o backend
/// (checkLoginLocation) diz que esta localização não é confiada — ver
/// AuthService.login().
enum _LoginStep { form, verify }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _rememberMe = true;
  bool _loading = false;
  _LoginStep _step = _LoginStep.form;
  String? _pendingVerificationId;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    setState(() => _loading = true);
    try {
      final result = await ref.read(authServiceProvider).login(
            email: _email.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      if (result.needsLocationVerification) {
        setState(() {
          _step = _LoginStep.verify;
          _pendingVerificationId = result.pendingVerificationId;
        });
      }
      // Se não precisar de verificação, o authStateProvider já mudou e
      // o router (routerProvider) trata sozinho do redirect para /controlo.
    } on fb.FirebaseAuthException catch (e) {
      _showError(_authErrorMessage(e));
    } catch (e) {
      _showError('Não foi possível entrar. Tenta novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitCode(String code) async {
    final verificationId = _pendingVerificationId;
    if (verificationId == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).confirmLoginLocation(
            verificationId: verificationId,
            code: code,
            rememberDevice: _rememberMe,
          );
      // Sucesso: o router avança sozinho para /controlo via authStateProvider.
    } catch (e) {
      _showError('Código incorreto ou expirado.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authErrorMessage(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou senha incorretos.';
      case 'too-many-requests':
        return 'Demasiadas tentativas. Tenta mais tarde.';
      default:
        return 'Não foi possível entrar. Tenta novamente.';
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: _step == _LoginStep.form ? _buildForm(context) : _buildVerify(context),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Image.asset('assets/logo.png', width: 120)),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Text('Bem-vindo!', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text(
                'Faça login para continuar',
                style: TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
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
          hint: 'A tua senha',
          obscurable: true,
          prefixIcon: Icons.lock_outline,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? true),
                  side: const BorderSide(color: SpeedLockColors.text2),
                ),
                const Text('Lembrar de mim', style: TextStyle(color: SpeedLockColors.text2, fontSize: 12.5)),
              ],
            ),
            GestureDetector(
              onTap: () => context.push('/recuperar-senha'),
              child: const Text(
                'Esqueci a senha',
                style: TextStyle(color: SpeedLockColors.accent, fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SpeedLockPrimaryButton(label: 'Entrar', onPressed: _submitLogin, loading: _loading),
        const SizedBox(height: 20),
        const Spacer(),
        Center(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
              children: [
                const TextSpan(text: 'Ainda não tem conta? '),
                TextSpan(
                  text: 'Crie uma!',
                  style: const TextStyle(color: SpeedLockColors.accent, fontWeight: FontWeight.w600),
                  recognizer: TapGestureRecognizerCompat(() => context.push('/criar-conta')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerify(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.mark_email_read_outlined, color: SpeedLockColors.accent, size: 40),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Text('Verifica o teu email', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Login a partir de uma localização nova.\nEnviámos um código de 6 dígitos para\n${_email.text}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SixDigitCodeInput(onCompleted: _submitCode),
        if (_loading) const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => setState(() => _step = _LoginStep.form),
          child: const Text('Voltar ao login', style: TextStyle(color: SpeedLockColors.text2)),
        ),
      ],
    );
  }
}

/// `RichText`/`TextSpan` exige um `GestureRecognizer` de vida gerida —
/// este pequeno wrapper evita ter de guardar/descartar manualmente um
/// `TapGestureRecognizer` só para um link inline.
class TapGestureRecognizerCompat extends GestureRecognizer {
  TapGestureRecognizerCompat(this.onTap);
  final VoidCallback onTap;

  @override
  void addPointer(PointerDownEvent event) {
    onTap();
  }

  @override
  String get debugDescription => 'tapGestureRecognizerCompat';

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void handleEvent(PointerEvent event) {}
}
