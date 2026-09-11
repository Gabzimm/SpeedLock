import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'scooter_protocol.dart';

/// Implementation for Ninebot / Segway-Ninebot (ES2, ES4, Max series...).
///
/// IMPORTANT — two different situations exist for this brand, and they are
/// NOT equally solvable:
///
/// 1. Older firmware: talks over a plain BLE UART-style characteristic,
///    same shape as the Xiaomi plugin. This is what the code below models.
///    UUIDs and command bytes are still PLACEHOLDERS — confirm against the
///    community protocol docs before real use.
///
/// 2. Newer firmware: wraps the same commands in Xiaomi's "miauth"
///    encryption layer (Ninebot and Xiaomi share lineage here). This
///    requires an auth token that is normally obtained through a linked
///    Mi Home/Xiaomi account — it is a materially bigger problem than
///    "find the right bytes", closer to reverse-engineering an auth
///    handshake. This class does NOT implement that path; see
///    `_negotiateMiAuth()` below, left unimplemented on purpose so it
///    fails loudly instead of pretending to work.
class NinebotProtocol implements ScooterProtocol {
  final FlutterReactiveBle _ble;
  final bool assumeEncryptedFirmware;
  NinebotProtocol(this._ble, {this.assumeEncryptedFirmware = false});

  @override
  String get brandName => 'Ninebot';

  // TODO: confirm real service/characteristic UUIDs for the target model.
  static final _serviceUuid =
      Uuid.parse('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final _writeCharUuid =
      Uuid.parse('6e400002-b5a3-f393-e0a9-e50e24dcca9e');
  static final _notifyCharUuid =
      Uuid.parse('6e400003-b5a3-f393-e0a9-e50e24dcca9e');

  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  final _connectionCtrl = StreamController<bool>.broadcast();
  final _telemetryCtrl = StreamController<ScooterTelemetry>.broadcast();
  String? _deviceId;

  @override
  Stream<bool> get connectionState => _connectionCtrl.stream;

  @override
  Stream<ScooterTelemetry> get telemetry => _telemetryCtrl.stream;

  @override
  Future<void> connect(String deviceId) async {
    _deviceId = deviceId;

    if (assumeEncryptedFirmware) {
      // Not implemented on purpose — see class doc comment above.
      throw UnimplementedError(
        'Ninebot miauth (encrypted firmware) is not implemented yet. '
        'This needs a Mi Home auth-token exchange, not just new UUIDs.',
      );
    }

    _connSub = _ble.connectToDevice(id: deviceId).listen((update) {
      final connected =
          update.connectionState == DeviceConnectionState.connected;
      _connectionCtrl.add(connected);
      if (connected) _subscribeToNotifications(deviceId);
    });
  }

  void _subscribeToNotifications(String deviceId) {
    final char = QualifiedCharacteristic(
      serviceId: _serviceUuid,
      characteristicId: _notifyCharUuid,
      deviceId: deviceId,
    );
    _notifySub = _ble.subscribeToCharacteristic(char).listen(_onNotification);
  }

  void _onNotification(List<int> bytes) {
    // TODO: parse the real frame format (header, checksum, payload offsets).
    if (bytes.length < 4) return;
    _telemetryCtrl.add(ScooterTelemetry(
      speedKmh: bytes[1].toDouble(),
      batteryPercent: bytes[2],
      locked: bytes[3] == 1,
    ));
  }

  Future<void> _write(List<int> bytes) async {
    if (_deviceId == null) return;
    final char = QualifiedCharacteristic(
      serviceId: _serviceUuid,
      characteristicId: _writeCharUuid,
      deviceId: _deviceId!,
    );
    await _ble.writeCharacteristicWithResponse(char, value: bytes);
  }

  @override
  Future<void> setSpeedLimit(int kmh) =>
      _write([0x5A, 0xA5, 0x02 /* TODO: real command byte */, kmh]);

  @override
  Future<void> lock() =>
      _write([0x5A, 0xA5, 0x10 /* TODO: real command byte */, 0x01]);

  @override
  Future<void> unlock() =>
      _write([0x5A, 0xA5, 0x10 /* TODO: real command byte */, 0x00]);

  @override
  Future<void> setLights(bool on) => _write(
      [0x5A, 0xA5, 0x20 /* TODO: real command byte */, on ? 0x01 : 0x00]);

  @override
  Future<void> honk() => _write([0x5A, 0xA5, 0x30 /* TODO: real command byte */]);

  @override
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    await _connSub?.cancel();
    _connectionCtrl.add(false);
  }
}
