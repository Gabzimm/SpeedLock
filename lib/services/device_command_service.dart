import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

/// Comandos que o ecrã de Controlo pode pedir. Os nomes têm de bater
/// certo com `MIN_LEVEL_FOR_COMMAND` em `server/lib/helpers.js`.
enum DeviceCommand { lock, unlock, setSpeedLimit, lights, horn }

extension on DeviceCommand {
  String get wireName => switch (this) {
        DeviceCommand.lock => 'lock',
        DeviceCommand.unlock => 'unlock',
        DeviceCommand.setSpeedLimit => 'setSpeedLimit',
        DeviceCommand.lights => 'lights',
        DeviceCommand.horn => 'horn',
      };
}

/// Payload assinado pelo backend, pronto a ser traduzido para os bytes
/// específicos do protocolo da marca (ver `services/ble/protocols/`) e
/// enviado por BLE. A app nunca gera isto sozinha.
class SignedCommand {
  final Map<String, dynamic> payload;
  final String signature;
  const SignedCommand({required this.payload, required this.signature});
}

/// Pede ao backend autorização (assinada) para executar um comando num
/// dispositivo. Isto implementa o lado do cliente do modelo "servidor
/// decide, app só pede" — ver a camada de autorização em
/// `server/routes/commands.js` para o que acontece quando o pedido é
/// suspeito.
///
/// Nota honesta: o backend valida a conta e a autorização, mas a própria
/// ligação BLE ao scooter continua a depender do que o firmware de cada
/// marca aceita — a maioria não verifica assinaturas do lado dele. Isto
/// protege a conta/API; não é uma garantia sobre o hop Bluetooth em si.
class DeviceCommandService {
  DeviceCommandService({ApiClient? api, FlutterSecureStorage? storage})
      : _api = api ?? ApiClient(),
        _storage = storage ?? const FlutterSecureStorage();

  final ApiClient _api;
  final FlutterSecureStorage _storage;
  final _random = Random.secure();

  String _offlineCapKey(String deviceId) => 'speedlock_offline_cap_$deviceId';

  String _generateNonce() {
    return List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<SignedCommand> request({
    required String deviceId,
    required DeviceCommand command,
    Map<String, dynamic>? params,
  }) async {
    final data = await _api.post('/requestDeviceCommand', {
      'deviceId': deviceId,
      'command': command.wireName,
      'params': params ?? {},
      'nonce': _generateNonce(),
    });

    return SignedCommand(
      payload: Map<String, dynamic>.from(data['payload'] as Map),
      signature: data['signature'] as String,
    );
  }

  /// Chamar no primeiro contacto BLE bem sucedido com uma trotinete
  /// (ecrã Ligar), antes de definir `connectedDeviceIdProvider`. Implementa
  /// "primeiro a ligar é o dono" do lado do backend — ver `/registerDevice`
  /// em server/routes/devices.js. Contas convidadas (anónimas) recebem
  /// `permission-denied`: só podem operar via `requestDeviceCommand` sem
  /// nunca "possuir" a trotinete.
  Future<bool> registerDevice({
    required String deviceId,
    String? brand,
    String? name,
  }) async {
    final data = await _api.post('/registerDevice', {
      'deviceId': deviceId,
      'brand': brand,
      'name': name,
    });
    return data['alreadyOwned'] == true;
  }

  /// Pede ao backend uma autorização de limite de velocidade válida
  /// offline (dias, não segundos como os comandos normais) e guarda-a no
  /// telemóvel. Chamar sempre que houver internet a sério — o próprio
  /// `setSpeedLimitOfflineAware` já faz isto sozinho a cada sucesso
  /// online, para a cache nunca ficar muito velha.
  Future<void> refreshOfflineCapability(String deviceId) async {
    final data = await _api.post('/issueOfflineSpeedLimitToken', {'deviceId': deviceId});
    await _storage.write(key: _offlineCapKey(deviceId), value: jsonEncode(data));
  }

  Future<bool> _hasValidOfflineCapability(String deviceId) async {
    final raw = await _storage.read(key: _offlineCapKey(deviceId));
    if (raw == null) return false;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final payload = data['payload'] as Map<String, dynamic>;
      final expiresAt = payload['expiresAt'] as int;
      return DateTime.now().millisecondsSinceEpoch < expiresAt;
    } catch (_) {
      return false;
    }
  }

  /// Ponto de entrada usado pelo ecrã Controlo para o limite de
  /// velocidade — o único comando que funciona sem internet (decisão
  /// deliberada: bloquear/desbloquear exigem sempre o servidor por
  /// perto). Tenta o caminho normal primeiro; só cai para a autorização
  /// offline em cache quando o pedido nem chega a ser respondido pelo
  /// backend (sem rede, timeout, servidor em baixo).
  ///
  /// Importante: uma recusa EXPLÍCITA do backend (nível insuficiente,
  /// conta sinalizada, nonce repetido...) chega como `ApiException` —
  /// essa nunca cai para a cache offline, senão a recusa online ficava
  /// sem efeito nenhum. Só erros que não vêm formatados pelo backend
  /// (falha de rede antes sequer de chegar lá) é que justificam tentar a
  /// autorização offline.
  Future<void> setSpeedLimitOfflineAware({
    required String deviceId,
    required int kmh,
  }) async {
    try {
      await request(deviceId: deviceId, command: DeviceCommand.setSpeedLimit, params: {'kmh': kmh});
      // Sucesso online: aproveita para renovar a cache offline em
      // segundo plano, sem bloquear a ação atual nem falhar por causa disto.
      unawaited(refreshOfflineCapability(deviceId).catchError((_) {}));
    } on ApiException {
      // Resposta explícita do backend a recusar — nunca contornar com a
      // cache offline.
      rethrow;
    } catch (e) {
      final offlineOk = await _hasValidOfflineCapability(deviceId);
      if (!offlineOk) rethrow;
      // Autorização offline válida: prossegue sem o backend. A app já
      // confirmou no passado (enquanto tinha internet) que esta conta
      // pode mudar o limite desta trotinete.
    }
  }
}
