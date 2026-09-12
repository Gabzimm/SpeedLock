import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../state/auth_provider.dart';
import '../../state/profile_provider.dart';

const _bannerPalette = [
  '#6D28D9', '#9333EA', '#DB2777', '#DC2626', '#D97706', '#059669', '#0891B2', '#2563EB',
];
const _accentPalette = [
  '#8B5CF6', '#A855F7', '#EC4899', '#F97316', '#22C55E', '#06B6D4', '#3B82F6', '#F4F2F7',
];

Color _fromHex(String hex) => Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);

class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  final _bioController = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _selectedBanner;
  String? _selectedAccent;
  bool _bioSynced = false;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final service = ref.read(profileServiceProvider);
      final url = await service.uploadAvatar(File(picked.path));
      await service.updateProfile(avatarUrl: url);
    } catch (e) {
      if (mounted) _showError('Não foi possível atualizar a foto.');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileServiceProvider).updateProfile(
            bio: _bioController.text.trim(),
            bannerColor: _selectedBanner,
            accentColor: _selectedAccent,
          );
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) _showError('Não foi possível guardar. Tenta novamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    await ref.read(authServiceProvider).logout();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(ownProfileDocProvider);
    final user = ref.watch(authServiceProvider).currentUser;

    return profileAsync.when(
      loading: () => const Scaffold(backgroundColor: SpeedLockColors.bgApp, body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        backgroundColor: SpeedLockColors.bgApp,
        body: Center(child: Text('Erro a carregar perfil: $e', style: const TextStyle(color: SpeedLockColors.danger))),
      ),
      data: (doc) {
        final bannerHex = doc?['bannerColor'] as String? ?? '#6D28D9';
        final accentHex = doc?['accentColor'] as String? ?? '#8B5CF6';
        final bio = doc?['bio'] as String? ?? '';
        final avatarUrl = doc?['avatarUrl'] as String?;

        if (!_bioSynced) {
          _bioController.text = bio;
          _bioSynced = true;
        }
        _selectedBanner ??= bannerHex;
        _selectedAccent ??= accentHex;

        return Scaffold(
          backgroundColor: SpeedLockColors.bgApp,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 120,
                        decoration: BoxDecoration(color: _fromHex(_editing ? _selectedBanner! : bannerHex)),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: Icon(_editing ? Icons.close : Icons.edit_outlined, color: Colors.white),
                          onPressed: () => setState(() => _editing = !_editing),
                        ),
                      ),
                      Positioned(
                        bottom: -40,
                        left: 20,
                        child: GestureDetector(
                          onTap: _uploadingPhoto ? null : _pickPhoto,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: SpeedLockColors.surface2,
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null
                                    ? Text(
                                        (user?.displayName?.isNotEmpty ?? false) ? user!.displayName![0].toUpperCase() : '?',
                                        style: const TextStyle(fontSize: 28, color: SpeedLockColors.text1),
                                      )
                                    : null,
                              ),
                              if (_uploadingPhoto)
                                const Positioned.fill(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _fromHex(accentHex),
                                      border: const Border.fromBorderSide(BorderSide(color: SpeedLockColors.bgApp, width: 3)),
                                    ),
                                    child: const Icon(Icons.camera_alt_outlined, size: 13, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 52),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Utilizador',
                          style: const TextStyle(color: SpeedLockColors.text1, fontWeight: FontWeight.w600, fontSize: 18),
                        ),
                        Text(user?.email ?? '', style: const TextStyle(color: SpeedLockColors.text2, fontSize: 12.5)),
                        const SizedBox(height: 16),
                        if (_editing) ...[
                          _buildEditor(bannerHex, accentHex),
                        ] else ...[
                          Text(
                            bio.isEmpty ? 'Sem bio ainda.' : bio,
                            style: TextStyle(
                              color: bio.isEmpty ? SpeedLockColors.text2 : SpeedLockColors.text1,
                              fontStyle: bio.isEmpty ? FontStyle.italic : FontStyle.normal,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        OutlinedButton(onPressed: _logout, child: const Text('Sair')),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditor(String bannerHex, String accentHex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bio', style: TextStyle(color: SpeedLockColors.text2, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _bioController,
          maxLength: 160,
          maxLines: 3,
          style: const TextStyle(color: SpeedLockColors.text1, fontSize: 13.5),
          decoration: const InputDecoration(hintText: 'Uma frase sobre ti…'),
        ),
        const SizedBox(height: 8),
        const Text('Cor do banner', style: TextStyle(color: SpeedLockColors.text2, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _ColorRow(
          palette: _bannerPalette,
          selected: _selectedBanner!,
          onSelected: (c) => setState(() => _selectedBanner = c),
        ),
        const SizedBox(height: 16),
        const Text('Cor de destaque', style: TextStyle(color: SpeedLockColors.text2, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _ColorRow(
          palette: _accentPalette,
          selected: _selectedAccent!,
          onSelected: (c) => setState(() => _selectedAccent = c),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar'),
          ),
        ),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.palette, required this.selected, required this.onSelected});
  final List<String> palette;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: palette.map((hex) {
        final isSelected = hex == selected;
        return GestureDetector(
          onTap: () => onSelected(hex),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _fromHex(hex),
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
          ),
        );
      }).toList(),
    );
  }
}
