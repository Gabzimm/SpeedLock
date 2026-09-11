import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

/// Resultado de uma tentativa de login. `needsLocationVerification` a
/// true significa que o backend viu esta conta a ser acedida de uma
/// cidade/país que ainda não conhece — a UI deve mostrar o ecrã de
/// código de 6 dígitos (o mesmo já usado na recuperação de senha) antes
/// de deixar entrar.
class LoginResult {
  final bool needsLocationVerification;
  final String? pendingVerificationId;

  const LoginResult({
    required this.needsLocationVerification,
    this.pendingVerificationId,
  });
}

/// Camada fina sobre a Firebase Auth + o backend próprio (Express na
/// VPS) que implementa o modelo "servidor decide, app só pede":
///
/// 1. A Firebase Auth confirma a password (é a única coisa que a vê).
/// 2. Uma rota nossa decide, do lado do servidor, se este login vem de
///    uma cidade/país confiado ou se precisa de código.
/// 3. A app NUNCA diz ao servidor onde acha que está — o servidor lê o
///    IP real do próprio pedido.
class AuthService {
  AuthService({
    fb.FirebaseAuth? auth,
    ApiClient? api,
    FlutterSecureStorage? storage,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _api = api ?? ApiClient(),
        _storage = storage ?? const FlutterSecureStorage();

  final fb.FirebaseAuth _auth;
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  static const _deviceTokenKey = 'speedlock_trusted_device_token';

  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();
  fb.User? get currentUser => _auth.currentUser;

  /// A conta é criada do lado do servidor (`/registerUser`), para que a
  /// localização inicial confiada venha do IP real do pedido — nunca de
  /// algo que a app diga sobre si própria. Depois de criada, a app abre
  /// a sua própria sessão local com o mesmo email/password.
  ///
  /// Exceção: se quem está a criar conta agora já tinha uma sessão de
  /// convidado (anónima — ver `signInAsGuest`), fazemos
  /// `linkWithCredential` em vez de criar um utilizador novo. Isto
  /// mantém o mesmo uid, para não perder a trotinete que o convidado já
  /// tinha ligado (ela ficou associada a esse uid, não a um email).
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      final credential = fb.EmailAuthProvider.credential(email: email, password: password);
      await current.linkWithCredential(credential);
      await _api.post('/finalizeGuestRegistration', {'name': name});
      return;
    }

    await _api.post('/registerUser', {
      'name': name,
      'email': email,
      'password': password,
    });

    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Passo 1 do login: valida a password na Firebase e depois pergunta
  /// ao backend se esta localização já é confiada para esta conta.
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);

    final deviceToken = await _storage.read(key: _deviceTokenKey);

    final data = await _api.post('/checkLoginLocation', {
      // Isto é só o token de "lembrar este dispositivo" — a localização
      // em si o servidor lê sozinho a partir do IP do pedido.
      'deviceToken': deviceToken,
    });

    final trusted = data['trusted'] == true;
    if (trusted) {
      return const LoginResult(needsLocationVerification: false);
    }

    return LoginResult(
      needsLocationVerification: true,
      pendingVerificationId: data['verificationId'] as String?,
    );
  }

  /// Passo 2 (só quando necessário): confirma o código de 6 dígitos
  /// enviado por email. Se `rememberDevice` for true, guarda um token
  /// local para não pedir verificação outra vez nesta rede/dispositivo
  /// durante o período de confiança (definido no servidor, ex: 30 dias).
  Future<void> confirmLoginLocation({
    required String verificationId,
    required String code,
    bool rememberDevice = true,
  }) async {
    final data = await _api.post('/confirmLoginVerification', {
      'verificationId': verificationId,
      'code': code,
      'rememberDevice': rememberDevice,
    });

    final newDeviceToken = data['deviceToken'] as String?;
    if (rememberDevice && newDeviceToken != null) {
      await _storage.write(key: _deviceTokenKey, value: newDeviceToken);
    }
  }

  /// Recuperação de senha — mesmo padrão de 3 passos do ecrã já
  /// desenhado: pedir código, confirmar código, definir nova senha. Não
  /// usamos o link de reset padrão da Firebase porque o mockup já tem um
  /// fluxo de código de 6 dígitos próprio.
  Future<void> requestPasswordReset(String email) async {
    await _api.post('/requestPasswordReset', {'email': email});
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _api.post('/confirmPasswordReset', {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
  }

  /// Sessão anónima para quem escolhe "Continuar sem login" — dá um uid
  /// válido (o backend exige sessão para qualquer comando) sem criar
  /// conta. O backend (`requestDeviceCommand`) restringe contas anónimas
  /// a apenas `setSpeedLimit` — ver README.
  Future<void> signInAsGuest() async {
    await _auth.signInAnonymously();
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Chamar quando o utilizador faz "sair de todos os dispositivos" ou
  /// reporta a conta como comprometida a partir das Configurações —
  /// invalida o token local (o servidor invalida a cópia dele à parte).
  Future<void> forgetThisDevice() async {
    await _storage.delete(key: _deviceTokenKey);
  }
}
