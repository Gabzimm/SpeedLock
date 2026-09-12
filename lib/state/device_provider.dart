import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble/protocols/scooter_protocol.dart';
import '../services/device_command_service.dart';
import 'connection_provider.dart';

/// Mirrors exactly the fields the Controlo screen mockup needs:
/// current speed, speed limit, lock state, lights, battery and mode.
class DeviceState {
  final bool connected;
  final double speedKmh;
  final int speedLimit;
  final bool locked;
  final bool lightsOn;
  final int batteryPercent;
  final String mode; // 'eco' | 'normal' | 'sport'

  const DeviceState({
    this.connected = false,
    this.speedKmh = 0,
    this.speedLimit = 20,
    this.locked = false,
    this.lightsOn = false,
    this.batteryPercent = 0,
    this.mode = 'normal',
  });

  DeviceState copyWith({
    bool? connected,
    double? speedKmh,
    int? speedLimit,
    bool? locked,
    bool? lightsOn,
    int? batteryPercent,
    String? mode,
  }) {
    return DeviceState(
      connected: connected ?? this.connected,
      speedKmh: speedKmh ?? this.speedKmh,
      speedLimit: speedLimit ?? this.speedLimit,
      locked: locked ?? this.locked,
      lightsOn: lightsOn ?? this.lightsOn,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      mode: mode ?? this.mode,
    );
  }
}

class DeviceNotifier extends StateNotifier<DeviceState> {
  final ScooterProtocol _protocol;
  final DeviceCommandService _commandService;
  final String? _deviceId;

  DeviceNotifier(this._protocol, this._commandService, this._deviceId)
      : super(const DeviceState()) {
    _protocol.connectionState.listen((c) {
      state = state.copyWith(connected: c);
    });
    _protocol.telemetry.listen((t) {
      state = state.copyWith(
        speedKmh: t.speedKmh,
        batteryPercent: t.batteryPercent,
        locked: t.locked,
      );
    });
  }

  static const _modeLimits = {'eco': 15, 'normal': 20, 'sport': 25};

  /// Asks the backend for a signed authorization before touching the
  /// scooter. This is the "server decides, app only asks" gate: if the
  /// account is unauthorized, flagged, or the request looks tampered,
  /// `DeviceCommandService` throws — the caller stops before ever
  /// reaching the BLE call below. (An earlier version of the backend
  /// returned a fake "success" instead of an error for these cases; that
  /// was a real bug, since this code only checks "did it throw?" before
  /// sending real BLE bytes — see functions/index.js for the fix.)
  ///
  /// Honest limitation: this protects the account/API layer. The actual
  /// BLE bytes below still go out using the plain params, because most
  /// consumer scooter firmware doesn't verify the signature itself — see
  /// the README for why that hop stays weaker than the account layer.
  Future<void> _authorize(
    DeviceCommand command,
    Map<String, dynamic> params,
  ) async {
    final deviceId = _deviceId;
    if (deviceId == null) {
      throw StateError(
        'No connected device id — connect via the Ligar screen before '
        'sending commands.',
      );
    }
    await _commandService.request(
      deviceId: deviceId,
      command: command,
      params: params,
    );
  }

  /// Igual a `_authorize`, mas só para `setSpeedLimit` — o único comando
  /// que também aceita uma autorização offline em cache quando o pedido
  /// online falha (ver `DeviceCommandService.setSpeedLimitOfflineAware`).
  /// Bloquear/desbloquear/luzes/buzina continuam sempre a exigir o
  /// backend por perto — decisão deliberada, não uma limitação técnica.
  Future<void> _authorizeSpeedLimitOfflineAware(int kmh) async {
    final deviceId = _deviceId;
    if (deviceId == null) {
      throw StateError(
        'No connected device id — connect via the Ligar screen before '
        'sending commands.',
      );
    }
    await _commandService.setSpeedLimitOfflineAware(deviceId: deviceId, kmh: kmh);
  }

  /// Same behaviour as the mode buttons in the Controlo mockup: switching
  /// mode sets a preset limit and pushes it to the scooter right away.
  Future<void> setMode(String mode) async {
    final limit = _modeLimits[mode] ?? state.speedLimit;
    await _authorizeSpeedLimitOfflineAware(limit);
    state = state.copyWith(mode: mode, speedLimit: limit);
    await _protocol.setSpeedLimit(limit);
  }

  Future<void> setSpeedLimit(int kmh) async {
    await _authorizeSpeedLimitOfflineAware(kmh);
    state = state.copyWith(speedLimit: kmh);
    await _protocol.setSpeedLimit(kmh);
  }

  Future<void> toggleLock() async {
    final next = !state.locked;
    await _authorize(next ? DeviceCommand.lock : DeviceCommand.unlock, {});
    state = state.copyWith(locked: next);
    next ? await _protocol.lock() : await _protocol.unlock();
  }

  Future<void> toggleLights() async {
    final next = !state.lightsOn;
    await _authorize(DeviceCommand.lights, {'on': next});
    state = state.copyWith(lightsOn: next);
    await _protocol.setLights(next);
  }

  Future<void> honk() async {
    await _authorize(DeviceCommand.horn, {});
    await _protocol.honk();
  }

  @override
  void dispose() {
    _protocol.disconnect();
    super.dispose();
  }
}

/// `activeProtocolProvider` and `connectedDeviceIdProvider` are set
/// together by the "Ligar" (auto-connect) screen: once a scan result is
/// picked, it stores the brand (resolving the protocol) and the BLE
/// device id here, then calls `protocol.connect(deviceId)`.
final deviceProvider = StateNotifierProvider<DeviceNotifier, DeviceState>(
  (ref) {
    final protocol = ref.watch(activeProtocolProvider);
    final deviceId = ref.watch(connectedDeviceIdProvider);
    final commandService = ref.watch(deviceCommandServiceProvider);
    return DeviceNotifier(protocol, commandService, deviceId);
  },
);
