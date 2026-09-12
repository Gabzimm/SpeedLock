import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../services/profile_service.dart';
import '../../state/auth_provider.dart';
import '../../state/connection_provider.dart';
import '../../state/device_provider.dart';
import '../../state/profile_provider.dart';
import '../widgets/speed_gauge.dart';

Color _fromHex(String hex) => Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);

class ControloScreen extends ConsumerWidget {
  const ControloScreen({super.key});

  void _showError(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Não foi possível $action. Tenta novamente.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceProvider);
    final notifier = ref.read(deviceProvider.notifier);
    final brand = ref.watch(activeBrandProvider);
    final deviceId = ref.watch(connectedDeviceIdProvider);
    final currentUid = ref.watch(authServiceProvider).currentUser?.uid;

    final stateLabel = !state.connected
        ? 'Desligado'
        : state.locked
            ? 'Bloqueado'
            : 'A circular';

    // Estimativa simples a partir da bateria — não vem de telemetria real
    // de autonomia (a maioria dos protocolos ainda não a expõe).
    final autonomiaKm = (state.batteryPercent / 100 * 20).round();

    return Scaffold(
      backgroundColor: SpeedLockColors.bgApp,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _AvatarButton(onTap: () => context.push('/perfil')),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          brand?.brandName ?? 'Dispositivo',
                          style: const TextStyle(color: SpeedLockColors.text1, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: state.connected ? SpeedLockColors.accent : SpeedLockColors.text2,
                              ),
                            ),
                            Text(
                              state.connected ? 'Ligado' : 'Desligado',
                              style: TextStyle(
                                color: state.connected ? SpeedLockColors.accent : SpeedLockColors.text2,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.battery_std, size: 15, color: SpeedLockColors.text2),
                      const SizedBox(width: 4),
                      Text('${state.batteryPercent}%', style: const TextStyle(color: SpeedLockColors.text2, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              if (deviceId != null) _OwnerBanner(deviceId: deviceId, currentUid: currentUid),
              const SizedBox(height: 12),
              Center(
                child: SpeedGauge(
                  speedKmh: state.speedKmh,
                  speedLimit: state.speedLimit,
                  stateLabel: stateLabel,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Limite de velocidade', style: TextStyle(color: SpeedLockColors.text2, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('${state.speedLimit} km/h', style: const TextStyle(color: SpeedLockColors.text1, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: SpeedLockColors.accent,
                  inactiveTrackColor: SpeedLockColors.surface2,
                  thumbColor: SpeedLockColors.accent,
                  overlayColor: SpeedLockColors.accent.withOpacity(0.2),
                ),
                child: Slider(
                  min: 6,
                  max: 25,
                  divisions: 19,
                  value: state.speedLimit.toDouble().clamp(6, 25),
                  onChanged: (v) => notifier.setSpeedLimit(v.round()),
                ),
              ),
              const SizedBox(height: 8),
              _ModeSegment(
                mode: state.mode,
                onChanged: (mode) async {
                  try {
                    await notifier.setMode(mode);
                  } catch (_) {
                    if (context.mounted) _showError(context, 'mudar de modo');
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: state.locked ? Icons.lock_outline : Icons.lock_open_outlined,
                      label: state.locked ? 'Desbloquear' : 'Bloquear',
                      onTap: () async {
                        try {
                          await notifier.toggleLock();
                        } catch (_) {
                          if (context.mounted) _showError(context, 'bloquear/desbloquear');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      icon: state.lightsOn ? Icons.lightbulb : Icons.lightbulb_outline,
                      label: 'Luzes',
                      onTap: () async {
                        try {
                          await notifier.toggleLights();
                        } catch (_) {
                          if (context.mounted) _showError(context, 'ligar as luzes');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.campaign_outlined,
                      label: 'Buzina',
                      onTap: () async {
                        try {
                          await notifier.honk();
                        } catch (_) {
                          if (context.mounted) _showError(context, 'tocar a buzina');
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: SpeedLockColors.surface1,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SpeedLockColors.lineAccent),
                ),
                child: Row(
                  children: [
                    _StatCell(label: 'Bateria', value: '${state.batteryPercent}%'),
                    _StatCell(label: 'Autonomia', value: '≈$autonomiaKm km'),
                    _StatCell(label: 'Marca', value: brand?.brandName ?? '—'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SpeedLockColors.surface2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.person_outline, size: 17, color: SpeedLockColors.text2),
        ),
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({required this.mode, required this.onChanged});
  final String mode;
  final ValueChanged<String> onChanged;

  static const _modes = ['eco', 'normal', 'sport'];
  static const _labels = {'eco': 'Eco', 'normal': 'Normal', 'sport': 'Sport'};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: SpeedLockColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpeedLockColors.line),
      ),
      child: Row(
        children: _modes.map((m) {
          final active = m == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(m),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? SpeedLockColors.surface2 : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _labels[m]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? SpeedLockColors.text1 : SpeedLockColors.text2,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SpeedLockColors.surface1,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SpeedLockColors.line),
          ),
          child: Column(
            children: [
              Icon(icon, size: 19, color: SpeedLockColors.text1),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: SpeedLockColors.text1, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: SpeedLockColors.text2, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: SpeedLockColors.text1, fontWeight: FontWeight.w600, fontSize: 13.5)),
        ],
      ),
    );
  }
}

/// Mostra o banner/foto/bio de quem é dono desta trotinete, quando quem
/// está ligado não é o próprio dono — é o efeito "ligo-me à trotinete do
/// João e vejo o perfil dele" pedido. Fica invisível (sem erro visível)
/// se a lista vier vazia — por exemplo antes de existir uma forma de
/// conceder acesso a outra conta, ou se o dispositivo ainda nem estiver
/// registado (ver README).
class _OwnerBanner extends ConsumerWidget {
  const _OwnerBanner({required this.deviceId, required this.currentUid});
  final String deviceId;
  final String? currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(deviceMembersProvider(deviceId));

    return membersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (members) {
        if (members.isEmpty) return const SizedBox.shrink();
        UserProfile? owner;
        for (final m in members) {
          if (m.isOwner) owner = m;
        }
        if (owner == null || owner.uid == currentUid) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _fromHex(owner.bannerColor).withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _fromHex(owner.accentColor).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: SpeedLockColors.surface2,
                  backgroundImage: owner.avatarUrl != null ? NetworkImage(owner.avatarUrl!) : null,
                  child: owner.avatarUrl == null
                      ? Text(owner.name.isNotEmpty ? owner.name[0].toUpperCase() : '?')
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trotinete de ${owner.name}',
                        style: const TextStyle(color: SpeedLockColors.text1, fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                      if (owner.bio.isNotEmpty)
                        Text(
                          owner.bio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: SpeedLockColors.text2, fontSize: 11.5),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
