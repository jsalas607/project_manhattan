import 'package:flutter/material.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/app_text_field.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _titleCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _lastnameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _loadingData = true;
  bool _saving = false;
  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _nameCtrl.dispose();
    _lastnameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await MockProfileApi.get();
    if (!mounted) return;
    _profile = profile;
    _titleCtrl.text = profile.title;
    _nameCtrl.text = profile.name;
    _lastnameCtrl.text = profile.lastname;
    _descCtrl.text = profile.description;
    setState(() => _loadingData = false);
  }

  Future<void> _onSave() async {
    setState(() => _saving = true);

    final updated = _profile.copyWith(
      title: _titleCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      lastname: _lastnameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
    );

    await MockProfileApi.update(updated);
    if (!mounted) return;

    setState(() {
      _profile = updated;
      _saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.verdeExito,
        content: Text(
          'Perfil actualizado',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textoOscuroAlto,
            fontWeight: FontWeight.w600,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Cerrar sesión', style: AppTypography.titleMedium),
        content: Text(
          '¿Seguro que quieres cerrar sesión?',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textoClaroMedio,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.textoClaroMedio)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cerrar sesión',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.rojoAlerta)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await MockAuthApi.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Perfil', style: AppTypography.titleLarge),
      ),
      body: _loadingData
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.naranjaAccion),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Título
                  AppTextField(
                    label: 'Título',
                    controller: _titleCtrl,
                    hintText: 'Ej: Gerente General',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 28),

                  // Foto circular
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.azulControl.withValues(alpha: 0.3),
                            border: Border.all(
                              color: AppColors.azulControl.withValues(alpha: 0.6),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 72,
                            color: AppColors.azulControl,
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.naranjaAccion,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: AppColors.textoClaroAlto,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _profile.username,
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Nombre
                  AppTextField(
                    label: 'Nombre',
                    controller: _nameCtrl,
                    hintText: 'Tu nombre',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Apellido
                  AppTextField(
                    label: 'Apellido',
                    controller: _lastnameCtrl,
                    hintText: 'Tu apellido',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Descripción
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Descripción', style: AppTypography.labelLarge),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _descCtrl,
                        maxLines: 4,
                        style: AppTypography.bodyLarge,
                        cursorColor: AppColors.naranjaAccion,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Sobre ti...',
                          hintStyle: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textoClaroMedio.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.naranjaAccion,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Guardar
                  ElevatedButton(
                    onPressed: _saving ? null : _onSave,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textoClaroAlto,
                            ),
                          )
                        : const Text('Guardar'),
                  ),
                  const SizedBox(height: 12),

                  // Cerrar sesión
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rojoAlerta,
                      side: BorderSide(
                        color: AppColors.rojoAlerta.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Cerrar sesión'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
