import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme.dart';
import '../../services/api_client.dart';
import '../../services/ble/protocols/protocol_registry.dart';
import '../../services/ble/protocols/usb_transport.dart';
import '../../services/ble/protocols/wifi_transport.dart';
import '../../state/access_request_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/connection_provider.dart';
import '../../state/device_provider.dart';

enum _ConnMethod { bluetooth, usb, wifi }

class LigarScreen extends ConsumerStatefulWidget {
  const LigarScreen({super.key});

  @override
  ConsumerState<LigarScreen> createState() => _LigarScreenState();
}

class _Found {
  _Found(this.device, this.brand);
  final DiscoveredDevice device;
  final BrandEntry brand;
}

class _LigarScreenState extends ConsumerState<LigarScreen> {
  _ConnMethod _method = _ConnMethod.bluetooth;

  // Bluetooth
  StreamSubscription<DiscoveredDevice>? _scanSub;
  final Map<String, _Found> _found = {};

  // USB
  List<UsbDevice> _usbDevices = [];
  bool _usbScanning = false;

  // Wi-Fi
  final _wifiHostController = TextEditingController(text: '192.168.4.1');
  final _wifiPortController = TextEditingController(text: '8080');

  String? _connectingId;
  String? _error;
  bool _showBrands = false;

  @override
  void initState() {
    super.initState();
    _startBluetoothScan();
  }

  void _switchMethod(_ConnMethod m) {
    setState(() {
      _method = m;
      _error = null;
    });
    if (m == _ConnMethod.bluetooth) _startBluetoothScan();
    if (m == _ConnMethod.usb) _scanUsb();
  }

  // ---------------------------------------------------------------------
  // Bluetooth
  // ---------------------------------------------------------------------

  void _startBluetoothScan() {
    setState(() => _error = null);
    _requestPermissionsAndScan();
  }

  Future<void> _requestPermissionsAndScan() async {
    // Android exige localização (scan BLE) e Bluetooth; iOS só Bluetooth.
    // As entradas correspondentes no AndroidManifest.xml/Info.plist ainda
    // não existem porque este projeto ainda não passou por
    // `flutter create .` — ver README.
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final denied = statuses.values.any((s) => s.isDenied || s.isPermanentlyDenied);
    if (denied) {
      if (mounted) {
        setState(() => _error = 'Permissões de Bluetooth/localização são necessárias para procurar trotinetes.');
      }
      return;
    }

    final ble = ref.read(bleClientProvider);
    _scanSub?.cancel();
    _scanSub = ble.scanForDevices(withServices: [], scanMode: ScanMode.lowLatency).listen(
      (device) {
        if (device.name.isEmpty) return;
        final brand = detectBrand(device.name);
        if (brand == null) return;
        setState(() => _found[device.id] = _Found(device, brand));
      },
      onError: (Object e) {
        setState(() => _error = 'Não foi possível procurar dispositivos: $e');
      },
    );
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _wifiHostController.dispose();
    _wifiPortController.dispose();
    super.dispose();
  }

  Future<void> _connect(_Found found) async {
    setState(() => _connectingId = found.device.id);
    try {
      // 1) liga a marca e o id BLE ao estado partilhado — é isto que faz
      // deviceProvider e o resto da app apontarem para o dispositivo certo.
      ref.read(manualProtocolProvider.notifier).state = null;
      ref.read(activeBrandProvider.notifier).state = found.brand;
      ref.read(connectedDeviceIdProvider.notifier).state = found.device.id;

      // 2) `activeProtocolProvider` fica em cache pelo Riverpod assim que
      // é lido a primeira vez — este `connect()` liga a MESMA instância
      // que o deviceProvider vai usar a seguir, não uma cópia à parte.
      final protocol = ref.read(activeProtocolProvider);
      await protocol.connect(found.device.id);

      // 3) registo de posse — só para contas normais. Convidados (sessão
      // anónima) não podem "possuir" trotinetes, só ajustar velocidade;
      // ver registerDevice em functions/index.js.
      final user = ref.read(authServiceProvider).currentUser;
      if (user != null && !user.isAnonymous) {
        try {
          await ref.read(deviceCommandServiceProvider).registerDevice(
                deviceId: found.device.id,
                brand: found.brand.brandName,
              );
          unawaited(
            ref.read(deviceCommandServiceProvider).refreshOfflineCapability(found.device.id).catchError((_) {}),
          );
        } on ApiException catch (e) {
          if (e.code == 'already-exists') {
            if (mounted) await _offerAccessRequest(found.device.id);
            return;
          }
          rethrow;
        }
      }

      if (mounted) context.go('/controlo');
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectingId = null;
          _error = 'Não foi possível ligar: $e';
        });
      }
    }
  }

  Future<void> _offerAccessRequest(String deviceId) async {
    setState(() => _connectingId = null);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpeedLockColors.surface1,
        title: const Text('Trotinete já registada', style: TextStyle(color: SpeedLockColors.text1)),
        content: const Text(
          'Esta trotinete já está associada a outra conta. Queres pedir '
          'acesso ao dono? Ele vai ver o teu pedido e decidir se aprova.',
          style: TextStyle(color: SpeedLockColors.text2, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: SpeedLockColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Pedir acesso', style: TextStyle(color: SpeedLockColors.accent)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      final alreadyHadAccess = await ref.read(accessRequestServiceProvider).requestAccess(deviceId: deviceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alreadyHadAccess
                ? 'Afinal já tinhas acesso — tenta ligar de novo.'
                : 'Pedido enviado. Vais poder usar assim que for aprovado.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível enviar o pedido. Tenta novamente.')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // USB
  // ---------------------------------------------------------------------

  Future<void> _scanUsb() async {
    setState(() => _usbScanning = true);
    try {
      final devices = await UsbTransport.listDevices();
      if (mounted) setState(() => _usbDevices = devices);
    } catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível procurar adaptadores USB: $e');
    } finally {
      if (mounted) setState(() => _usbScanning = false);
    }
  }

  Future<void> _connectUsb(UsbDevice device) async {
    final id = 'usb-${device.deviceId}';
    setState(() => _connectingId = id);
    try {
      final protocol = UsbScooterProtocol('USB (marca por identificar)', device);
      ref.read(manualProtocolProvider.notifier).state = protocol;
      ref.read(activeBrandProvider.notifier).state = null;
      ref.read(connectedDeviceIdProvider.notifier).state = id;
      await protocol.connect(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Porta USB aberta. Os comandos (bloquear, limite...) ainda vão falhar até o protocolo desta marca ser confirmado com hardware real.',
            ),
          ),
        );
        context.go('/controlo');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível ligar por USB: $e');
    } finally {
      if (mounted) setState(() => _connectingId = null);
    }
  }

  // ---------------------------------------------------------------------
  // Wi-Fi
  // ---------------------------------------------------------------------

  Future<void> _connectWifi() async {
    final host = _wifiHostController.text.trim();
    final port = int.tryParse(_wifiPortController.text.trim()) ?? 8080;
    final id = '$host:$port';
    setState(() => _connectingId = id);
    try {
      final protocol = WifiScooterProtocol('Wi-Fi (marca por identificar)', defaultHost: host, defaultPort: port);
      ref.read(manualProtocolProvider.notifier).state = protocol;
      ref.read(activeBrandProvider.notifier).state = null;
      ref.read(connectedDeviceIdProvider.notifier).state = id;
      await protocol.connect(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ligado por Wi-Fi. Os comandos ainda vão falhar até o protocolo desta marca ser confirmado com hardware real.',
            ),
          ),
        );
        context.go('/controlo');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível ligar por Wi-Fi: $e');
    } finally {
      if (mounted) setState(() => _connectingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpeedLockColors.bgApp,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RadarHeader(
                scanning: _method == _ConnMethod.bluetooth && _found.isEmpty && _error == null,
                icon: switch (_method) {
                  _ConnMethod.bluetooth => Icons.bluetooth_searching,
                  _ConnMethod.usb => Icons.usb,
                  _ConnMethod.wifi => Icons.wifi,
                },
              ),
              const SizedBox(height: 16),
              _MethodTabs(current: _method, onSelected: _switchMethod),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: SpeedLockColors.danger, fontSize: 13)),
                const SizedBox(height: 12),
              ],
              Expanded(child: _buildBody()),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _showBrands = !_showBrands),
                child: Text(
                  '${_showBrands ? 'Esconder' : 'Ver'} marcas compatíveis (${supportedBrands.length})',
                  style: const TextStyle(color: SpeedLockColors.accent),
                ),
              ),
              if (_showBrands) _BrandList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_method) {
      case _ConnMethod.bluetooth:
        final devices = _found.values.toList();
        if (devices.isEmpty && _error == null) {
          return const Center(
            child: Text('À procura de trotinetes por perto…', style: TextStyle(color: SpeedLockColors.text2, fontSize: 13.5)),
          );
        }
        return ListView.separated(
          itemCount: devices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final found = devices[i];
            final connecting = _connectingId == found.device.id;
            return _DeviceTile(
              icon: Icons.electric_scooter,
              title: found.brand.brandName,
              subtitle: found.brand.implemented ? found.device.name : '${found.device.name} · protocolo por confirmar',
              connecting: connecting,
              onTap: connecting ? null : () => _connect(found),
            );
          },
        );

      case _ConnMethod.usb:
        if (_usbScanning) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_usbDevices.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nenhum adaptador USB-série encontrado.\nLiga a trotinete por cabo OTG e tenta de novo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _scanUsb, child: const Text('Procurar de novo')),
              ],
            ),
          );
        }
        return ListView.separated(
          itemCount: _usbDevices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final device = _usbDevices[i];
            final id = 'usb-${device.deviceId}';
            final connecting = _connectingId == id;
            return _DeviceTile(
              icon: Icons.usb,
              title: device.productName ?? 'Adaptador USB-série',
              subtitle: 'ID ${device.deviceId} · marca por identificar',
              connecting: connecting,
              onTap: connecting ? null : () => _connectUsb(device),
            );
          },
        );

      case _ConnMethod.wifi:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Liga por Wi-Fi a controladores que expõem o próprio ponto de acesso (padrão comum em placas DIY tipo ESP32).',
                style: TextStyle(color: SpeedLockColors.text2, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _wifiHostController,
                style: const TextStyle(color: SpeedLockColors.text1),
                decoration: const InputDecoration(labelText: 'Endereço IP', hintText: '192.168.4.1'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _wifiPortController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: SpeedLockColors.text1),
                decoration: const InputDecoration(labelText: 'Porta', hintText: '8080'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _connectingId != null ? null : _connectWifi,
                child: _connectingId != null
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Ligar'),
              ),
            ],
          ),
        );
    }
  }
}

class _MethodTabs extends StatelessWidget {
  const _MethodTabs({required this.current, required this.onSelected});
  final _ConnMethod current;
  final ValueChanged<_ConnMethod> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget tab(_ConnMethod m, IconData icon, String label) {
      final active = m == current;
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelected(m),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: active ? SpeedLockColors.surface2 : SpeedLockColors.surface1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? SpeedLockColors.accent : SpeedLockColors.line),
            ),
            child: Column(
              children: [
                Icon(icon, size: 16, color: active ? SpeedLockColors.accent : SpeedLockColors.text2),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 11, color: active ? SpeedLockColors.text1 : SpeedLockColors.text2)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(_ConnMethod.bluetooth, Icons.bluetooth, 'Bluetooth'),
        tab(_ConnMethod.usb, Icons.usb, 'USB'),
        tab(_ConnMethod.wifi, Icons.wifi, 'Wi-Fi'),
      ],
    );
  }
}

class _RadarHeader extends StatelessWidget {
  const _RadarHeader({required this.scanning, required this.icon});
  final bool scanning;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 66,
          height: 66,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (scanning)
                const SizedBox(
                  width: 66,
                  height: 66,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: SpeedLockColors.lineAccent),
                ),
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: SpeedLockColors.surface1),
                child: Icon(icon, color: SpeedLockColors.accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Ligar', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text(
          'Escolhe o método de ligação',
          style: TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
        ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.connecting,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool connecting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SpeedLockColors.surface1,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SpeedLockColors.lineAccent),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: SpeedLockColors.surface2,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: SpeedLockColors.text2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: SpeedLockColors.text1, fontWeight: FontWeight.w600, fontSize: 13.5)),
                    Text(subtitle, style: const TextStyle(color: SpeedLockColors.text2, fontSize: 11.5)),
                  ],
                ),
              ),
              if (connecting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: SpeedLockColors.accent),
                )
              else
                const Icon(Icons.chevron_right, color: SpeedLockColors.text2, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: SpeedLockColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SpeedLockColors.line),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.all(4),
        itemCount: supportedBrands.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: SpeedLockColors.line),
        itemBuilder: (context, i) {
          final b = supportedBrands[i];
          final label = b.implemented ? 'Pronto' : (b.priority ? 'Prioritário' : 'Por confirmar');
          final color = b.implemented
              ? SpeedLockColors.accent
              : (b.priority ? Colors.orangeAccent : SpeedLockColors.text2);
          return ListTile(
            dense: true,
            title: Text(b.brandName, style: const TextStyle(color: SpeedLockColors.text1, fontSize: 13)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }
}
