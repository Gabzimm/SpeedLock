import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../services/access_request_service.dart';
import '../../services/device_service.dart';
import '../../state/access_request_provider.dart';
import '../../state/device_management_provider.dart';

const _levelLabels = {
  'owner': 'Dono',
  'admin': 'Admin',
  'user': 'Utilizador',
  'temporary': 'Temporário',
  'limited': 'Limitado',
};

class DispositivosScreen extends ConsumerStatefulWidget {
  const DispositivosScreen({super.key});

  @override
  ConsumerState<DispositivosScreen> createState() => _DispositivosScreenState();
}

class _DispositivosScreenState extends ConsumerState<DispositivosScreen> {
  late Future<List<MyDevice>> _devicesFuture;
  late Future<List<IncomingAccessRequest>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _devicesFuture = ref.read(deviceServiceProvider).listMyDevices();
    _requestsFuture = ref.read(accessRequestServiceProvider).listIncoming();
  }

  Future<void> _respond(IncomingAccessRequest req, bool approve) async {
    String level = 'limited';
    if (approve) {
      final chosen = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          backgroundColor: SpeedLockColors.surface1,
          title: Text('Nível de acesso para ${req.requesterName}', style: const TextStyle(color: SpeedLockColors.text1, fontSize: 15)),
          children: _levelLabels.entries
              .where((e) => e.key != 'owner')
              .map(
                (e) => SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(e.key),
                  child: Text(e.value, style: const TextStyle(color: SpeedLockColors.text1)),
                ),
              )
              .toList(),
        ),
      );
      if (chosen == null) return;
      level = chosen;
    }

    try {
      await ref.read(accessRequestServiceProvider).respond(requestId: req.requestId, approve: approve, level: level);
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Acesso concedido.' : 'Pedido recusado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível responder. Tenta novamente.')),
        );
      }
    }
  }

  Future<void> _toggleStolen(MyDevice device) async {
    final markingStolen = !device.stolen;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpeedLockColors.surface1,
        title: Text(
          markingStolen ? 'Reportar como roubada?' : 'Marcar como recuperada?',
          style: const TextStyle(color: SpeedLockColors.text1),
        ),
        content: Text(
          markingStolen
              ? 'Fica registado que esta trotinete foi roubada. Isto ainda não bloqueia nada remotamente — é só um registo.'
              : 'Volta ao estado normal.',
          style: const TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar', style: TextStyle(color: SpeedLockColors.text2))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(markingStolen ? 'Reportar' : 'Marcar', style: const TextStyle(color: SpeedLockColors.danger))),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(deviceServiceProvider).setStolenStatus(deviceId: device.deviceId, stolen: markingStolen);
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível atualizar. Tenta novamente.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpeedLockColors.bgApp,
      appBar: AppBar(
        backgroundColor: SpeedLockColors.bgApp,
        title: const Text('Dispositivos', style: TextStyle(color: SpeedLockColors.text1)),
        iconTheme: const IconThemeData(color: SpeedLockColors.text1),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FutureBuilder<List<IncomingAccessRequest>>(
              future: _requestsFuture,
              builder: (context, snap) {
                final requests = snap.data ?? const [];
                if (requests.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pedidos de acesso', style: TextStyle(color: SpeedLockColors.text2, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    ...requests.map((req) => _RequestCard(
                          request: req,
                          onApprove: () => _respond(req, true),
                          onDeny: () => _respond(req, false),
                        )),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
            const Text('As tuas trotinetes', style: TextStyle(color: SpeedLockColors.text2, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            FutureBuilder<List<MyDevice>>(
              future: _devicesFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return const Text('Não foi possível carregar as trotinetes.', style: TextStyle(color: SpeedLockColors.danger));
                }
                final devices = snap.data ?? const [];
                if (devices.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Ainda não ligaste a nenhuma trotinete. Usa o ecrã Ligar para associar a primeira.',
                      style: TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
                    ),
                  );
                }
                return Column(children: devices.map((d) => _DeviceCard(device: d, onToggleStolen: () => _toggleStolen(d))).toList());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onApprove, required this.onDeny});
  final IncomingAccessRequest request;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpeedLockColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SpeedLockColors.lineAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(request.requesterName, style: const TextStyle(color: SpeedLockColors.text1, fontWeight: FontWeight.w600, fontSize: 13.5)),
          const SizedBox(height: 2),
          Text('quer acesso à trotinete ${request.deviceId}', style: const TextStyle(color: SpeedLockColors.text2, fontSize: 12)),
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('"${request.message}"', style: const TextStyle(color: SpeedLockColors.text2, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: onDeny, child: const Text('Recusar')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(onPressed: onApprove, child: const Text('Aprovar')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onToggleStolen});
  final MyDevice device;
  final VoidCallback onToggleStolen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpeedLockColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: device.stolen ? SpeedLockColors.danger : SpeedLockColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: SpeedLockColors.surface2, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.electric_scooter, color: SpeedLockColors.text2, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.brand ?? device.deviceId, style: const TextStyle(color: SpeedLockColors.text1, fontWeight: FontWeight.w600, fontSize: 13.5)),
                Text(
                  device.stolen ? 'Reportada como roubada' : (_levelLabels[device.level] ?? device.level),
                  style: TextStyle(color: device.stolen ? SpeedLockColors.danger : SpeedLockColors.text2, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (device.isOwner)
            IconButton(
              icon: Icon(
                device.stolen ? Icons.check_circle_outline : Icons.report_gmailerrorred_outlined,
                color: device.stolen ? SpeedLockColors.accent : SpeedLockColors.text2,
                size: 20,
              ),
              onPressed: onToggleStolen,
            ),
        ],
      ),
    );
  }
}
