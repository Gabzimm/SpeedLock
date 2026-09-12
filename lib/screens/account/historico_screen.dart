import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../services/device_service.dart';
import '../../state/device_management_provider.dart';

const _actionLabels = {
  'registered': 'Registada como tua',
  'lock': 'Bloqueada',
  'unlock': 'Desbloqueada',
  'setSpeedLimit': 'Limite de velocidade alterado',
  'lights': 'Luzes',
  'horn': 'Buzina',
  'access_granted': 'Acesso concedido',
  'reported_stolen': 'Reportada como roubada',
  'marked_recovered': 'Marcada como recuperada',
};

const _actionIcons = {
  'registered': Icons.electric_scooter,
  'lock': Icons.lock_outline,
  'unlock': Icons.lock_open_outlined,
  'setSpeedLimit': Icons.speed_outlined,
  'lights': Icons.lightbulb_outline,
  'horn': Icons.campaign_outlined,
  'access_granted': Icons.person_add_alt_1_outlined,
  'reported_stolen': Icons.report_gmailerrorred_outlined,
  'marked_recovered': Icons.check_circle_outline,
};

class HistoricoScreen extends ConsumerStatefulWidget {
  const HistoricoScreen({super.key});

  @override
  ConsumerState<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends ConsumerState<HistoricoScreen> {
  late Future<List<HistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(deviceServiceProvider).listMyHistory();
  }

  String _describe(HistoryEntry e) {
    final label = _actionLabels[e.action] ?? e.action;
    if (e.action == 'setSpeedLimit' && e.extra?['kmh'] != null) {
      return '$label para ${e.extra!['kmh']} km/h';
    }
    if (e.action == 'access_granted' && e.extra?['level'] != null) {
      return '$label (${e.extra!['level']})';
    }
    return label;
  }

  String _formatWhen(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'agora mesmo';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    if (diff.inDays < 7) return 'há ${diff.inDays} d';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpeedLockColors.bgApp,
      appBar: AppBar(
        backgroundColor: SpeedLockColors.bgApp,
        title: const Text('Histórico', style: TextStyle(color: SpeedLockColors.text1)),
        iconTheme: const IconThemeData(color: SpeedLockColors.text1),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = ref.read(deviceServiceProvider).listMyHistory());
          await _future;
        },
        child: FutureBuilder<List<HistoryEntry>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: const [
                  Text('Não foi possível carregar o histórico.', style: TextStyle(color: SpeedLockColors.danger)),
                ],
              );
            }
            final entries = snap.data ?? const [];
            if (entries.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: const [
                  SizedBox(height: 40),
                  Center(
                    child: Text(
                      'Ainda não há nada aqui — ações como bloquear, mudar o\nlimite de velocidade ou ligar pela primeira vez\naparecem aqui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SpeedLockColors.text2, fontSize: 13.5, height: 1.5),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final e = entries[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SpeedLockColors.surface1,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SpeedLockColors.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: SpeedLockColors.surface2, borderRadius: BorderRadius.circular(10)),
                        child: Icon(_actionIcons[e.action] ?? Icons.info_outline, size: 16, color: SpeedLockColors.text2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_describe(e), style: const TextStyle(color: SpeedLockColors.text1, fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(
                              '${e.actorName} · ${e.brand ?? e.deviceId}',
                              style: const TextStyle(color: SpeedLockColors.text2, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      Text(_formatWhen(e.dateTime), style: const TextStyle(color: SpeedLockColors.text2, fontSize: 11)),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
