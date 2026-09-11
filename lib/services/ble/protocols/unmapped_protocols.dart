import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'scooter_protocol.dart';

/// Every class in this file represents a brand that DOES have an official
/// Bluetooth-connected app (confirmed), but for which no public protocol
/// documentation exists today. Rather than inventing plausible-looking
/// UUIDs and command bytes with no basis, each stub compiles and fits the
/// plugin architecture, but fails loudly with a clear message if someone
/// tries to use it before the real protocol has been captured.
///
/// PRIORIDADE (pedido explícito): Kukirin, Havee, YUME, Halo Knight e
/// NAVEE são as próximas a atacar a sério. Durante a pesquisa inicial
/// notámos que várias marcas genéricas chinesas descrevem a app oficial
/// em termos quase idênticos, sugerindo que partilham o mesmo hardware
/// OEM ("DanDan") por trás — vale a pena sniffar uma destas primeiro
/// (ex: Kukirin, mais fácil de encontrar em segunda mão) e testar se o
/// mesmo protocolo serve para as outras antes de repetir o trabalho
/// marca a marca.
///
/// How to "graduate" one of these to a real implementation:
///  1. Install the brand's official app on a spare phone.
///  2. Use an Android BLE HCI snoop log (or nRF Connect + a sniffer) while
///     operating every control in the app (lock, lights, speed limit...).
///  3. Identify the service/characteristic UUIDs and the byte pattern for
///     each command — same process already done for Xiaomi/Ninebot.
///  4. Replace the stub below with a real class following xiaomi_protocol.dart
///     as the template, and register it in protocol_registry.dart.
class _NotYetMappedProtocol implements ScooterProtocol {
  final FlutterReactiveBle _ble;
  @override
  final String brandName;
  _NotYetMappedProtocol(this._ble, this.brandName);

  final _connectionCtrl = StreamController<bool>.broadcast();
  final _telemetryCtrl = StreamController<ScooterTelemetry>.broadcast();

  @override
  Stream<bool> get connectionState => _connectionCtrl.stream;
  @override
  Stream<ScooterTelemetry> get telemetry => _telemetryCtrl.stream;

  Never _notMapped(String action) => throw UnimplementedError(
      '$brandName: BLE protocol not reverse-engineered yet ($action). '
      'See the how-to in unmapped_protocols.dart before wiring this up.');

  @override
  Future<void> connect(String deviceId) async => _notMapped('connect');
  @override
  Future<void> disconnect() async => _notMapped('disconnect');
  @override
  Future<void> setSpeedLimit(int kmh) async => _notMapped('setSpeedLimit');
  @override
  Future<void> lock() async => _notMapped('lock');
  @override
  Future<void> unlock() async => _notMapped('unlock');
  @override
  Future<void> setLights(bool on) async => _notMapped('setLights');
  @override
  Future<void> honk() async => _notMapped('honk');
}

class KukirinProtocol extends _NotYetMappedProtocol {
  KukirinProtocol(FlutterReactiveBle ble) : super(ble, 'Kukirin');
}

class HaveeProtocol extends _NotYetMappedProtocol {
  HaveeProtocol(FlutterReactiveBle ble) : super(ble, 'Havee');
}

class YumeProtocol extends _NotYetMappedProtocol {
  YumeProtocol(FlutterReactiveBle ble) : super(ble, 'YUME');
}

class HaloKnightProtocol extends _NotYetMappedProtocol {
  HaloKnightProtocol(FlutterReactiveBle ble) : super(ble, 'Halo Knight');
}

/// NIU is architecturally different from the rest: its ecosystem leans on
/// a cloud/account API rather than local BLE commands for most features.
/// A real implementation likely needs an HTTP client talking to NIU's
/// cloud API (see the reverse-engineered niu-app-api project) in addition
/// to, or instead of, direct BLE — flagged here so it isn't confused with
/// a "just find the UUIDs" job like the others.
class NiuProtocol extends _NotYetMappedProtocol {
  NiuProtocol(FlutterReactiveBle ble) : super(ble, 'NIU');
}

class DualtronProtocol extends _NotYetMappedProtocol {
  DualtronProtocol(FlutterReactiveBle ble) : super(ble, 'Dualtron');
}

class EngweProtocol extends _NotYetMappedProtocol {
  EngweProtocol(FlutterReactiveBle ble) : super(ble, 'ENGWE');
}

class IScooterProtocol extends _NotYetMappedProtocol {
  IScooterProtocol(FlutterReactiveBle ble) : super(ble, 'iScooter');
}

class NaveeProtocol extends _NotYetMappedProtocol {
  NaveeProtocol(FlutterReactiveBle ble) : super(ble, 'NAVEE');
}

class ApolloProtocol extends _NotYetMappedProtocol {
  ApolloProtocol(FlutterReactiveBle ble) : super(ble, 'Apollo');
}

class HiboyProtocol extends _NotYetMappedProtocol {
  HiboyProtocol(FlutterReactiveBle ble) : super(ble, 'Hiboy');
}

class PureElectricProtocol extends _NotYetMappedProtocol {
  PureElectricProtocol(FlutterReactiveBle ble) : super(ble, 'Pure Electric');
}
