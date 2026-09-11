import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:http/http.dart' as http;
import '../app/api_config.dart';

/// Mesma forma que `FirebaseFunctionsException` tinha (`code` +
/// `message`), para os `catch` já escritos nos ecrãs continuarem a
/// funcionar trocando só o tipo capturado. Os `code` são os mesmos
/// valores que o servidor já usava com `functions.HttpsError` — ver
/// `server/lib/httpError.js`.
class ApiException implements Exception {
  final String code;
  final String message;
  const ApiException(this.code, this.message);

  @override
  String toString() => 'ApiException($code): $message';
}

/// Cliente HTTP para o backend próprio. Substitui `cloud_functions` —
/// a Firebase Auth e o Firestore continuam exatamente iguais, só a
/// "compute" (o que antes eram Cloud Functions) passou a correr na VPS.
class ApiClient {
  ApiClient({String? baseUrl, fb.FirebaseAuth? auth})
      : _baseUrl = baseUrl ?? apiBaseUrl,
        _auth = auth ?? fb.FirebaseAuth.instance;

  final String _baseUrl;
  final fb.FirebaseAuth _auth;

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? data]) async {
    final headers = {'Content-Type': 'application/json'};

    final user = _auth.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      headers['Authorization'] = 'Bearer $token';
    }

    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: headers,
            body: jsonEncode(data ?? {}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      // Falha antes de chegar ao servidor (sem rede, DNS, timeout...) —
      // não é uma recusa explícita do backend. Quem chama (ex:
      // DeviceCommandService.setSpeedLimitOfflineAware) distingue isto
      // de um ApiException para decidir se cai para a cache offline.
      rethrow;
    }

    Map<String, dynamic> body = const {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    }

    if (response.statusCode >= 400) {
      throw ApiException(
        body['code'] as String? ?? 'internal',
        body['message'] as String? ?? 'Erro desconhecido.',
      );
    }
    return body;
  }
}
