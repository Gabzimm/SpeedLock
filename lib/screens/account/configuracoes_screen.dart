import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../state/auth_provider.dart';
import '../../state/connection_provider.dart';
import '../../state/device_management_provider.dart';

class ConfiguracoesScreen extends ConsumerWidget {
  const ConfiguracoesScreen({super.key});

  Future<void> _forgetDevice(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpeedLockColors.surface1,
        title: const Text('Esquecer este dispositivo?', style: TextStyle(color: SpeedLockColors.text1)),
        content: const Text(
          'Da próxima vez que fizeres login a partir daqui, vai pedir um '
          'código de verificação por email outra vez — tal como num '
          'aparelho novo.',
          style: TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar', style: TextStyle(color: SpeedLockColors.text2))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Esquecer', style: TextStyle(color: SpeedLockColors.accent))),
        ],
      ),
    );
    if (confirmar == true) {
      await ref.read(authServiceProvider).forgetThisDevice();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feito.')));
      }
    }
  }

  Future<void> _reportStolen(BuildContext context, WidgetRef ref) async {
    final connectedId = ref.read(connectedDeviceIdProvider);
    if (connectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liga-te primeiro à trotinete que queres reportar (ecrã Dispositivos também mostra as tuas).')),
      );
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpeedLockColors.surface1,
        title: const Text('Reportar como roubada?', style: TextStyle(color: SpeedLockColors.text1)),
        content: const Text(
          'Fica registado que esta trotinete foi roubada. Isto ainda não '
          'bloqueia nada remotamente (falta GPS/GSM) — é só um registo, '
          'visível também no ecrã Dispositivos.',
          style: TextStyle(color: SpeedLockColors.text2, fontSize: 13.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar', style: TextStyle(color: SpeedLockColors.text2))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Reportar', style: TextStyle(color: SpeedLockColors.danger))),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(deviceServiceProvider).setStolenStatus(deviceId: connectedId, stolen: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reportada como roubada.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível reportar (só o dono pode).')),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authServiceProvider).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: SpeedLockColors.bgApp,
      appBar: AppBar(
        backgroundColor: SpeedLockColors.bgApp,
        title: const Text('Configurações', style: TextStyle(color: SpeedLockColors.text1)),
        iconTheme: const IconThemeData(color: SpeedLockColors.text1),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionLabel('Conta'),
          _SettingsTile(
            icon: Icons.directions_car_filled_outlined,
            title: 'Dispositivos',
            subtitle: 'Trotinetes e pedidos de acesso',
            onTap: () => context.push('/dispositivos'),
          ),
          _SettingsTile(
            icon: Icons.history,
            title: 'Histórico',
            onTap: () => context.push('/historico'),
          ),
          _SettingsTile(
            icon: Icons.phonelink_lock_outlined,
            title: 'Esquecer este dispositivo',
            subtitle: 'Volta a pedir verificação por email no próximo login',
            onTap: () => _forgetDevice(context, ref),
          ),
          const SizedBox(height: 16),
          _SectionLabel('Segurança'),
          _SettingsTile(
            icon: Icons.report_gmailerrorred_outlined,
            title: 'Reportar como roubada',
            subtitle: 'Aplica-se à trotinete ligada agora',
            danger: true,
            onTap: () => _reportStolen(context, ref),
          ),
          const SizedBox(height: 16),
          _SectionLabel('Sobre'),
          const _SettingsTile(icon: Icons.description_outlined, title: 'Termos de serviço', subtitle: 'Ainda por publicar (site em desenvolvimento)'),
          const _SettingsTile(icon: Icons.privacy_tip_outlined, title: 'Política de privacidade', subtitle: 'Ainda por publicar (site em desenvolvimento)'),
          const SizedBox(height: 16),
          _SettingsTile(icon: Icons.logout, title: 'Sair', danger: true, onTap: () => _logout(context, ref)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(label, style: const TextStyle(color: SpeedLockColors.text2, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, this.subtitle, this.onTap, this.danger = false});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? SpeedLockColors.danger : SpeedLockColors.text1;
    return ListTile(
      leading: Icon(icon, color: danger ? SpeedLockColors.danger : SpeedLockColors.text2, size: 20),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13.5)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(color: SpeedLockColors.text2, fontSize: 11.5)) : null,
      trailing: onTap != null ? const Icon(Icons.chevron_right, color: SpeedLockColors.text2, size: 18) : null,
      onTap: onTap,
    );
  }
}
