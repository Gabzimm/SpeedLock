import 'api_client.dart';

/// Um pedido de acesso a um dispositivo — visto do lado de quem pediu.
class MyAccessRequest {
  final String requestId;
  final String deviceId;
  final String status; // 'pending' | 'approved' | 'denied'
  final String? grantedLevel;

  const MyAccessRequest({
    required this.requestId,
    required this.deviceId,
    required this.status,
    this.grantedLevel,
  });

  factory MyAccessRequest.fromMap(Map<String, dynamic> map) {
    return MyAccessRequest(
      requestId: map['requestId'] as String,
      deviceId: map['deviceId'] as String,
      status: map['status'] as String? ?? 'pending',
      grantedLevel: map['grantedLevel'] as String?,
    );
  }
}

/// Um pedido de acesso — visto do lado do dono, que tem de aprovar ou
/// recusar.
class IncomingAccessRequest {
  final String requestId;
  final String deviceId;
  final String requesterUid;
  final String requesterName;
  final String? message;

  const IncomingAccessRequest({
    required this.requestId,
    required this.deviceId,
    required this.requesterUid,
    required this.requesterName,
    this.message,
  });

  factory IncomingAccessRequest.fromMap(Map<String, dynamic> map) {
    return IncomingAccessRequest(
      requestId: map['requestId'] as String,
      deviceId: map['deviceId'] as String,
      requesterUid: map['requesterUid'] as String,
      requesterName: map['requesterName'] as String? ?? 'Utilizador',
      message: map['message'] as String?,
    );
  }
}

/// Implementa o fluxo "pedi para ligar à trotinete do João": quem tenta
/// ligar-se a um dispositivo que já tem dono pode pedir acesso; o dono
/// vê o pedido e aprova (com um nível) ou recusa. Tudo decidido no
/// backend — ver server/routes/devices.js.
class AccessRequestService {
  AccessRequestService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Devolve `true` se já tinhas acesso (nada a pedir). Se já existir um
  /// pedido pendente teu para este dispositivo, não cria outro — apenas
  /// devolve o mesmo requestId.
  Future<bool> requestAccess({required String deviceId, String? message}) async {
    final data = await _api.post('/requestDeviceAccess', {
      'deviceId': deviceId,
      'message': message,
    });
    return data['alreadyHasAccess'] == true;
  }

  Future<List<IncomingAccessRequest>> listIncoming() async {
    final data = await _api.post('/listIncomingAccessRequests');
    final list = (data['requests'] as List).cast<Map<dynamic, dynamic>>();
    return list.map((m) => IncomingAccessRequest.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  Future<List<MyAccessRequest>> listMine() async {
    final data = await _api.post('/listMyAccessRequests');
    final list = (data['requests'] as List).cast<Map<dynamic, dynamic>>();
    return list.map((m) => MyAccessRequest.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  /// `level` só importa quando `approve` é true — um dos 4 níveis já
  /// usados em `requestDeviceCommand` (limited/temporary/user/admin).
  /// Recusar não precisa de nível nenhum.
  Future<void> respond({
    required String requestId,
    required bool approve,
    String level = 'limited',
  }) async {
    await _api.post('/respondToAccessRequest', {
      'requestId': requestId,
      'approve': approve,
      'level': level,
    });
  }
}
