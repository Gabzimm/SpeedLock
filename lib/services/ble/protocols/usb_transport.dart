import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'scooter_protocol.dart';

/// Transporte USB genérico — liga-se a um adaptador USB-série real (a
/// maioria das trotinetes com porta de configuração por cabo usa um chip
/// série comum, ex. CP210x/CH340). Isto abre e fala com a porta a
/// sério: bytes são mesmo escritos/lidos no cabo.
///
/// O que continua por confirmar, marca a marca, é o CÓDIGO dos comandos
/// — que bytes mandar para bloquear, mudar o limite, etc. Essa parte
/// exige o mesmo trabalho de engenharia reversa com hardware real que já
/// descrevemos para o BLE (ver unmapped_protocols.dart). Sem isso, abrir
/// a porta funciona mas não há "linguagem" comum para conversar com uma
/// trotinete específica.
class UsbTransport {
  UsbPort? _port;
  StreamSubscription<Uint8List>? _sub;
  final _dataCtrl = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get onData => _dataCtrl.stream;

  /// Lista os adaptadores USB-série já ligados ao telemóvel (via cabo
  /// OTG). Vazio não significa erro — pode só não haver nada ligado.
  static Future<List<UsbDevice>> listDevices() => UsbSerial.listDevices();

  Future<bool> connect(UsbDevice device) async {
    _port = await device.create();
    if (_port == null) return false;
    final opened = await _port!.open();
    if (!opened) return false;
    await _port!.setDTR(true);
    await _port!.setRTS(true);
    // 115200 8N1 é o valor mais comum para consolas de depuração de
    // controladores de trotinete — ajustar se a marca usar outro.
    await _port!.setPortParameters(
      115200,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );
    _sub = _port!.inputStream?.listen(_dataCtrl.add);
    return true;
  }

  Future<void> write(Uint8List bytes) async {
    await _port?.write(bytes);
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    await _port?.close();
  }
}

/// Implementa `ScooterProtocol` sobre USB — a ligação é real, os
/// comandos não (ver aviso na classe acima). Serve para já poderes
/// testar/demonstrar a ligação USB; cada método de comando falha com
/// uma mensagem clara em vez de mandar bytes inventados para o veículo.
class UsbScooterProtocol implements ScooterProtocol {
  UsbScooterProtocol(this.brandName, this._device);

  @override
  final String brandName;
  final UsbDevice _device;
  final _transport = UsbTransport();
  final _connectionCtrl = StreamController<bool>.broadcast();
  final _telemetryCtrl = StreamController<ScooterTelemetry>.broadcast();

  @override
  Stream<bool> get connectionState => _connectionCtrl.stream;
  @override
  Stream<ScooterTelemetry> get telemetry => _telemetryCtrl.stream;

  @override
  Future<void> connect(String deviceId) async {
    final ok = await _transport.connect(_device);
    _connectionCtrl.add(ok);
    if (!ok) {
      throw StateError('Não foi possível abrir a porta USB-série.');
    }
  }

  @override
  Future<void> disconnect() async {
    await _transport.disconnect();
    _connectionCtrl.add(false);
  }

  Never _noCodec(String action) => throw UnimplementedError(
      '$brandName por USB: porta aberta com sucesso, mas o formato dos '
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
