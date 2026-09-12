import 'api_client.dart';

class MyDevice {
  final String deviceId;
  final String? brand;
  final String? name;
  final bool isOwner;
  final String level;
  final bool stolen;

  const MyDevice({
    required this.deviceId,
    this.brand,
    this.name,
    required this.isOwner,
    required this.level,
    required this.stolen,
  });

  factory MyDevice.fromMap(Map<String, dynamic> map) {
    return MyDevice(
      deviceId: map['deviceId'] as String,
      brand: map['brand'] as String?,
      name: map['name'] as String?,
      isOwner: map['isOwner'] as bool? ?? false,
      level: map['level'] as String? ?? 'limited',
      stolen: map['stolen'] as bool? ?? false,
    );
  }
}

/// Gestão de trotinetes associadas à conta — lista (próprias e
/// partilhadas) e o "Reportar como roubada" das Configurações.
class DeviceService {
  DeviceService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<List<MyDevice>> listMyDevices() async {
    final data = await _api.post('/listMyDevices');
    final list = (data['devices'] as List).cast<Map<dynamic, dynamic>>();
    return list.map((m) => MyDevice.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  /// Só o dono pode chamar isto — o backend recusa qualquer outra conta.
  /// Não desliga nada sozinho (ainda não há GPS/GSM remoto no projeto);
  /// serve para ficar registado e visível a quem partilha a trotinete.
  Future<void> setStolenStatus({required String deviceId, required bool stolen}) async {
    await _api.post('/setStolenStatus', {'deviceId': deviceId, 'stolen': stolen});
  }

  Future<List<HistoryEntry>> listMyHistory() async {
    final data = await _api.post('/listMyHistory');
    final list = (data['entries'] as List).cast<Map<dynamic, dynamic>>();
    return list.map((m) => HistoryEntry.fromMap(Map<String, dynamic>.from(m))).toList();
  }
}

class HistoryEntry {
  final String deviceId;
  final String? brand;
  final String action;
  final String actorName;
  final int timestamp;
  final Map<String, dynamic>? extra;

  const HistoryEntry({
    required this.deviceId,
    this.brand,
    required this.action,
    required this.actorName,
    required this.timestamp,
    this.extra,
  });

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      deviceId: map['deviceId'] as String,
      brand: map['brand'] as String?,
      action: map['action'] as String? ?? '',
      actorName: map['actorName'] as String? ?? 'Utilizador',
      timestamp: map['timestamp'] as int? ?? 0,
      extra: map['extra'] != null ? Map<String, dynamic>.from(map['extra'] as Map) : null,
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);
}
