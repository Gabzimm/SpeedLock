import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'api_client.dart';

/// Personalização de perfil: banner, cor de destaque, foto, bio. Guardado
/// em `users/{uid}` no Firestore, mas só através da rota `/updateProfile`
/// do backend — nunca por escrita direta do cliente, para que a
/// validação (tamanho da bio, formato da cor) não dependa só da app.
class UserProfile {
  final String uid;
  final String name;
  final String bio;
  final String bannerColor;
  final String accentColor;
  final String? avatarUrl;
  final bool isOwner;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.bio,
    required this.bannerColor,
    required this.accentColor,
    this.avatarUrl,
    this.isOwner = false,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String,
      name: map['name'] as String? ?? 'Utilizador',
      bio: map['bio'] as String? ?? '',
      bannerColor: map['bannerColor'] as String? ?? '#6D28D9',
      accentColor: map['accentColor'] as String? ?? '#8B5CF6',
      avatarUrl: map['avatarUrl'] as String?,
      isOwner: map['isOwner'] as bool? ?? false,
    );
  }
}

class ProfileService {
  ProfileService({
    fb.FirebaseAuth? auth,
    ApiClient? api,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _api = api ?? ApiClient(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final fb.FirebaseAuth _auth;
  final ApiClient _api;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  /// Stream do documento de perfil do próprio utilizador — usar num
  /// `StreamProvider` para o ecrã Perfil refletir alterações em tempo
  /// real. Isto continua a falar DIRETO com o Firestore (não passa pelo
  /// backend na VPS) — é a parte que ficou "gerida pela Firebase" na
  /// decisão de manter Auth/Firestore lá.
  Stream<Map<String, dynamic>?> watchOwnProfileDoc() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _firestore.collection('users').doc(uid).snapshots().map((s) => s.data());
  }

  Future<void> updateProfile({String? bio, String? bannerColor, String? accentColor, String? avatarUrl}) async {
    await _api.post('/updateProfile', {
      if (bio != null) 'bio': bio,
      if (bannerColor != null) 'bannerColor': bannerColor,
      if (accentColor != null) 'accentColor': accentColor,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
  }

  /// Faz upload da foto para a Firebase Storage e devolve o URL — quem
  /// chamar ainda tem de passar esse URL a `updateProfile` para o
  /// gravar (a validação do valor fica centralizada lá).
  Future<String> uploadAvatar(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sem sessão.');
    final ref = _storage.ref('avatars/$uid.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  /// Perfis de quem tem acesso a este dispositivo (dono + autorizados) —
  /// é isto que mostra a foto/banner/bio de outra pessoa quando estás
  /// ligado à trotinete dela. Só responde se tu próprio já tiveres
  /// acesso a esse dispositivo (ver `/getDeviceMembersProfiles` no backend).
  Future<List<UserProfile>> getDeviceMembers(String deviceId) async {
    final data = await _api.post('/getDeviceMembersProfiles', {'deviceId': deviceId});
    final members = (data['members'] as List).cast<Map<dynamic, dynamic>>();
    return members.map((m) => UserProfile.fromMap(Map<String, dynamic>.from(m))).toList();
  }
}
