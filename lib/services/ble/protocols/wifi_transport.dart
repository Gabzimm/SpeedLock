import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'scooter_protocol.dart';

/// Transporte Wi-Fi genérico — liga por TCP a um IP/porta reais. Bytes
/// são mesmo enviados/recebidos pelo socket.
///
/// Nota honesta: nenhuma das 13 marcas da lista do projeto está
/// confirmada a controlar a trotinete por Wi-Fi — todas as apps oficiais
/// conhecidas usam BLE. Isto existe sobretudo para compatibilidade
/// futura, por exemplo controladores DIY baseados em ESP32/ESP8266, que
/// costumam expor o seu próprio ponto de acesso Wi-Fi (tipicamente
/// `192.168.4.1`) — daí os valores por omissão abaixo. Tal como no USB,
/// falta o codec de comandos de qualquer marca real: a ligação funciona,
/// a "conversa" ainda não existe.
class WifiTransport {
  Socket? _socket;
  final _dataCtrl = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get onData => _dataCtrl.stream;

  Future<bool> connect(String host, int port) async {
    try {
      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      _socket!.listen(_dataCtrl.add, onError: (_) {}, cancelOnError: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> write(Uint8List bytes) async {
    _socket?.add(bytes);
    await _socket?.flush();
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }
}

/// Implementa `ScooterProtocol` sobre Wi-Fi — a ligação é real, os
/// comandos não (ver aviso na classe acima).
class WifiScooterProtocol implements ScooterProtocol {
  WifiScooterProtocol(this.brandName, {this.defaultHost = '192.168.4.1', this.defaultPort = 8080});

  @override
  final String brandName;
  final String defaultHost;
  final int defaultPort;
  final _transport = WifiTransport();
  final _connectionCtrl = StreamController<bool>.broadcast();
  final _telemetryCtrl = StreamController<ScooterTelemetry>.broadcast();

  @override
  Stream<bool> get connectionState => _connectionCtrl.stream;
  @override
  Stream<ScooterTelemetry> get telemetry => _telemetryCtrl.stream;

  @override
  Future<void> connect(String deviceId) async {
    // `deviceId` pode vir como "host:porta"; sem isso, usa os valores
    // por omissão (o padrão de um ponto de acesso Wi-Fi tipo ESP32).
    final parts = deviceId.contains(':') ? deviceId.split(':') : null;
    final host = parts?[0] ?? defaultHost;
    final port = parts != null ? int.tryParse(parts[1]) ?? defaultPort : defaultPort;

    final ok = await _transport.connect(host, port);
    _connectionCtrl.add(ok);
    if (!ok) {
      throw StateError('Não foi possível ligar por Wi-Fi a $host:$port.');
    }
  }

  @override
  Future<void> disconnect() async {
    await _transport.disconnect();
    _connectionCtrl.add(false);
  }

  Never _noCodec(String action) => throw UnimplementedError(
      '$brandName por Wi-Fi: ligação aberta com sucesso, mas o formato dos '
      'comandos ($action) ainda não foi confirmado com hardware real.');

  @override
  Future<void> setSpeedLimit(int kmh) async => _noCodec('setSpeedLimit');
  @override
  Future<void> lock() async => _noCodec('lock');
  @override
  Future<void> unlock() async => _noCodec('unlock');
  @override
  Future<void> setLights(bool on) async => _noCodec('setLights');
  @override
  Future<void> honk() async => _noCodec('honk');
}
