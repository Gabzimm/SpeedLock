import 'dart:async';

/// Common contract every scooter-brand BLE implementation must follow.
/// To support a new brand, create a new class that implements this
/// interface — nothing else in the app (state, screens) needs to change.
abstract class ScooterProtocol {
  /// Human-readable brand name, e.g. "Kukirin", "Xiaomi".
  String get brandName;

  /// Emits true/false as the BLE connection + handshake succeeds or drops.
  Stream<bool> get connectionState;

  /// Live telemetry pushed by the scooter (speed, battery, lock state).
  Stream<ScooterTelemetry> get telemetry;

  Future<void> connect(String deviceId);
  Future<void> disconnect();

  /// Writes a NEW persistent speed limit (km/h) to the scooter's own
  /// controller/firmware, so it is respected even after the phone
  /// disconnects — this is what makes the limit "stick" while offline.
  Future<void> setSpeedLimit(int kmh);

  Future<void> lock();
  Future<void> unlock();
  Future<void> setLights(bool on);
  Future<void> honk();
}

class ScooterTelemetry {
  final double speedKmh;
  final int batteryPercent;
  final bool locked;

  const ScooterTelemetry({
    required this.speedKmh,
    required this.batteryPercent,
    required this.locked,
  });
}
