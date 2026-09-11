import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Stream do utilizador atual da Firebase — null quer dizer sem sessão.
/// O router e o ecrã Boas-vindas devem observar isto para decidir entre
/// mostrar o fluxo de login ou ir direto para o Controlo.
final authStateProvider = StreamProvider<fb.User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});
