import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble/protocols/scooter_protocol.dart';
import '../services/ble/protocols/protocol_registry.dart';
import '../services/device_command_service.dart';

/// Single shared BLE client for the whole app.
final bleClientProvider = Provider<FlutterReactiveBle>((ref) {
  return FlutterReactiveBle();
});

/// Set by the Ligar (auto-connect) screen once `detectBrand()` finds a
/// match for the scanned device's advertised name.
final activeBrandProvider = StateProvider<BrandEntry?>((ref) => null);

/// The BLE device id (platform-specific address) of whichever scooter
/// the Ligar screen picked from the scan results. Set alongside
/// `activeBrandProvider`, right before calling `protocol.connect(id)`.
/// `deviceProvider` reads this to authorize commands against the right
/// device on the backend — keep the two in sync.
final connectedDeviceIdProvider = StateProvider<String?>((ref) => null);

final deviceCommandServiceProvider = Provider<DeviceCommandService>((ref) {
  return DeviceCommandService();
});

/// Definido diretamente pelo ecrã Ligar quando a ligação não é BLE
/// (USB/Wi-Fi) — nesses casos não há um `BrandEntry` (a marca não foi
/// detetada por nome anunciado, foi escolhida à mão pela pessoa). Quando
/// isto está definido, `activeProtocolProvider` usa-o em vez de
/// construir a partir de `activeBrandProvider`.
final manualProtocolProvider = StateProvider<ScooterProtocol?>((ref) => null);

/// Resolves to the concrete ScooterProtocol for whichever brand was
/// detected. Reading this before a brand is set is a programming error
/// (there is nothing to connect to yet), so it throws clearly instead of
/// returning a fake/default protocol.
final activeProtocolProvider = Provider<ScooterProtocol>((ref) {
  final manual = ref.watch(manualProtocolProvider);
  if (manual != null) return manual;

  final brand = ref.watch(activeBrandProvider);
  final ble = ref.watch(bleClientProvider);
  if (brand == null) {
    throw StateError(
      'activeProtocolProvider read before a brand was detected/selected '
      'on the Ligar screen.',
    );
  }
  return brand.build(ble);
});
