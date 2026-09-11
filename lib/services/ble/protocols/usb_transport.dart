import 'dart:async';
import 'dart:typed_data';
import 'scooter_protocol.dart';

/// Suporte USB temporariamente desativado nesta versão.
///
/// O pacote `usb_serial` (que aqui abria mesmo a porta série a sério)
/// ficou desatualizado — a sua configuração Android chama `jcenter()`,
/// um repositório que já não existe, e quebra a compilação com
/// ferramentas Android atuais (ver o erro real de build: "Could not
/// find method jcenter()"). Como nenhuma marca confirmada (Xiaomi,
/// Ninebot) usa USB para comandos — todas usam Bluetooth — a opção mais
/// segura foi desativar isto por agora em vez de travar todo o resto da
/// app à espera de um substituto.
///
/// Esta classe mantém a mesma forma que tinha antes (`UsbDevice`,
/// `UsbTransport`, `UsbScooterProtocol`) para o resto do código (ver
/// ligar_screen.dart) continuar a compilar sem alterações — só o
/// comportamento por dentro mudou: `listDevices()` devolve sempre uma
/// lista vazia, e qualquer tentativa de ligar falha com uma mensagem
/// clara em vez de silenciosa.
///
/// Para reativar a sério: procurar uma biblioteca USB-série mantida e
/// compatível com Android Gradle Plugin atual (ex.: `usb_serial_android`
/// mais recente, ou um plugin escrito à mão via platform channel), e
/// substituir só o conteúdo deste ficheiro — a interface pública
/// (`UsbDevice`, `UsbTransport`, `UsbScooterProtocol`) pode manter-se
/// igual, para não mexer em mais nada.
class UsbDevice {
  const UsbDevice({this.deviceId, this.productName, this.vendorId, this.productId});
  final int? deviceId;
  final String? productName;
  final int? vendorId;
  final int? productId;
}

class UsbTransport {
  final _dataCtrl = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get onData => _dataCtrl.stream;

  /// Sempre vazio nesta versão — ver aviso no topo do ficheiro.
  static Future<List<UsbDevice>> listDevices() async => const [];

  Future<bool> connect(UsbDevice device) async => false;

  Future<void> write(Uint8List bytes) async {}

  Future<void> disconnect() async {}
}

/// Implementa `ScooterProtocol` sobre USB — nesta versão, `connect`
/// falha sempre com uma mensagem clara (ver aviso no topo do ficheiro).
class UsbScooterProtocol implements ScooterProtocol {
  UsbScooterProtocol(this.brandName, this._device);

  @override
  final String brandName;
  // ignore: unused_field
  final UsbDevice _device;
  final _connectionCtrl = StreamController<bool>.broadcast();
  final _telemetryCtrl = StreamController<ScooterTelemetry>.broadcast();

  @override
  Stream<bool> get connectionState => _connectionCtrl.stream;
  @override
  Stream<ScooterTelemetry> get telemetry => _telemetryCtrl.stream;

  @override
  Future<void> connect(String deviceId) async {
    _connectionCtrl.add(false);
    throw StateError(
      'Suporte USB temporariamente indisponível nesta versão de teste — '
      'ver aviso em usb_transport.dart.',
    );
  }

  @override
  Future<void> disconnect() async {
    _connectionCtrl.add(false);
  }

  Never _noCodec(String action) => throw UnimplementedError(
      'USB temporariamente indisponível nesta versão ($action).');

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
