import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/profile_service.dart';
import 'auth_provider.dart';

final profileServiceProvider = Provider<ProfileService>((ref) => ProfileService());

/// Documento de perfil do próprio utilizador em tempo real — null antes
/// da primeira personalização (o ecrã Perfil deve tratar isso como
/// "valores por omissão", não como erro.
final ownProfileDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  // Reagir a login/logout: sem isto, o stream ficaria preso ao uid antigo.
  ref.watch(authStateProvider);
  return ref.watch(profileServiceProvider).watchOwnProfileDoc();
});

/// Perfis de quem tem acesso ao dispositivo `deviceId` — usado pelo ecrã
/// Controlo para mostrar o banner/foto/bio do dono quando quem está
/// ligado não é o próprio dono. Falha silenciosamente (lista vazia) se
/// o dispositivo ainda não estiver registado ou a conta não tiver acesso
/// — não é suposto isto derrubar o ecrã Controlo por um erro de rede.
final deviceMembersProvider = FutureProvider.family<List<UserProfile>, String>((ref, deviceId) async {
  try {
    return await ref.watch(profileServiceProvider).getDeviceMembers(deviceId);
  } catch (_) {
    return const [];
  }
});
