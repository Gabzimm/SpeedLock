import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'scooter_protocol.dart';
import 'xiaomi_protocol.dart';
import 'ninebot_protocol.dart';
import 'unmapped_protocols.dart';

/// Single source of truth for "which brands does the app know about, and
/// how do we tell them apart during a BLE scan".
///
/// `namePrefix` is matched against the advertised BLE device name found
/// during the scan on the Ligar (auto-connect) screen. Only Xiaomi's and
/// Ninebot's prefixes below are based on values commonly seen in public
/// write-ups — every other prefix is a PLACEHOLDER and must be confirmed
/// by actually scanning a real unit of that brand (any BLE scanner app,
/// e.g. nRF Connect, will show the advertised name).
class BrandEntry {
  final String brandName;
  final String namePrefix;
  final bool implemented;

  /// Marca como próxima a atacar a sério (reverse-engineering com
  /// hardware real). Não significa "já funciona" — só ajuda a UI e quem
  /// for trabalhar nisto a saber por onde começar.
  final bool priority;
  final ScooterProtocol Function(FlutterReactiveBle ble) build;

  const BrandEntry({
    required this.brandName,
    required this.namePrefix,
    required this.implemented,
    this.priority = false,
    required this.build,
  });
}

final List<BrandEntry> supportedBrands = [
  BrandEntry(
    brandName: 'Xiaomi',
    namePrefix: 'MIScooter', // seen in community write-ups
    implemented: true,
    build: (ble) => XiaomiProtocol(ble),
  ),
  BrandEntry(
    brandName: 'Ninebot',
    namePrefix: 'Ninebot-', // seen in community write-ups
    implemented: true,
    build: (ble) => NinebotProtocol(ble),
  ),
  BrandEntry(
    brandName: 'Kukirin',
    namePrefix: 'KUKIRIN', // TODO: confirm against a real unit
    implemented: false,
    priority: true,
    build: (ble) => KukirinProtocol(ble),
  ),
  BrandEntry(
    brandName: 'Havee',
    namePrefix: 'HAVEE', // TODO: confirm against a real unit
    implemented: false,
    priority: true,
    build: (ble) => HaveeProtocol(ble),
  ),
  BrandEntry(
    brandName: 'YUME',
    namePrefix: 'YUME', // TODO: confirm against a real unit
    implemented: false,
    priority: true,
    build: (ble) => YumeProtocol(ble),
  ),
  BrandEntry(
    brandName: 'Halo Knight',
    namePrefix: 'HaloKnight', // TODO: confirm against a real unit
    implemented: false,
    priority: true,
    build: (ble) => HaloKnightProtocol(ble),
  ),
  BrandEntry(
    brandName: 'NIU',
    namePrefix: 'NIU', // TODO: confirm — likely also needs cloud API, see NiuProtocol doc
    implemented: false,
    build: (ble) => NiuProtocol(ble),
  ),
  BrandEntry(
    brandName: 'Dualtron',
    namePrefix: 'Dualtron', // TODO: confirm against a real unit
    implemented: false,
    build: (ble) => DualtronProtocol(ble),
  ),
  BrandEntry(
    brandName: 'ENGWE',
    namePrefix: 'ENGWE', // TODO: confirm against a real unit
    implemented: false,
    build: (ble) => EngweProtocol(ble),
  ),
  BrandEntry(
    brandName: 'iScooter',
    namePrefix: 'iScooter', // TODO: confirm against a real unit
    implemented: false,
    build: (ble) => IScooterProtocol(ble),
  ),
  BrandEntry(
    brandName: 'NAVEE',
    namePrefix: 'NAVEE', // TODO: confirm against a real unit
    implemented: false,
    priority: true,
    build: (ble) => NaveeProtocol(ble),
  ),
  BrandEntry(
    brandName: 'Apollo',
    namePrefix: 'Apollo', // TODO: confirm against a real unit
    implemented: false,
    build: (ble) => ApolloProtocol(ble),
  ),
  BrandEntry(
    brandName: 'Hiboy',
    namePrefix: 'Hiboy', // TODO: confirm against a real unit
    implemented: false,
    build: (ble) => HiboyProtocol(ble),
  ),
  BrandEntry(
    brandName: 'Pure Electric',
    namePrefix: 'PureElectric', // TODO: confirm against a real unit
    implemented: false,
    build: (ble) => PureElectricProtocol(ble),
  ),
];

/// Called from the Ligar screen once a BLE scan result comes in.
/// Returns null if the advertised name doesn't match any known brand yet.
BrandEntry? detectBrand(String advertisedName) {
  for (final brand in supportedBrands) {
    if (advertisedName.startsWith(brand.namePrefix)) return brand;
  }
  return null;
}
