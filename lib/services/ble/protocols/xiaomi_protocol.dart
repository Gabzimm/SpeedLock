import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'scooter_protocol.dart';

/// Implementation for Xiaomi M365 / Pro / Pro 2.
///
/// IMPORTANT: the UUIDs and command bytes below are PLACEHOLDERS to show
/// the shape of the solution. Xiaomi does not publish this protocol
/// officially — before this touches real hardware, every TODO must be
/// replaced with values confirmed against the community
/// reverse-engineering docs (e.g. the M365-BLE-PROTOCOL project) and
/// tested on an actual scooter. Do not ship these bytes as-is.
class XiaomiProtocol implements ScooterProtocol {
  final FlutterReactiveBle _ble;
  XiaomiProtocol(this._ble);

  @override
  String get brandName => 'Xiaomi';

  // TODO: confirm the real service/characteristic UUIDs for the target model.
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
    // This is a placeholder decode so the state layer has something to
    // consume while the real byte layout is being mapped out.
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
      _write([0x55, 0xAA, 0x02 /* TODO: real command byte */, kmh]);

  @override
  Future<void> lock() =>
      _write([0x55, 0xAA, 0x10 /* TODO: real command byte */, 0x01]);

  @override
  Future<void> unlock() =>
      _write([0x55, 0xAA, 0x10 /* TODO: real command byte */, 0x00]);

  @override
  Future<void> setLights(bool on) => _write(
      [0x55, 0xAA, 0x20 /* TODO: real command byte */, on ? 0x01 : 0x00]);

  @override
  Future<void> honk() => _write([0x55, 0xAA, 0x30 /* TODO: real command byte */]);

  @override
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    await _connSub?.cancel();
    _connectionCtrl.add(false);
  }
}
