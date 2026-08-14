import 'package:flutter/material.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import 'duenos_screen.dart';
import 'login_screen.dart';
import 'restaurant_list_screen.dart';

/// Pantalla de entrada del superadmin (la plataforma). Solo la ve él:
/// elige entre usar la app normalmente o administrar a sus clientes (dueños).
class SuperadminHubScreen extends StatelessWidget {
  const SuperadminHubScreen({super.key, required this.user});

  final AppUser user;

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Cerrar sesión?', style: AppTypography.titleMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textoClaroMedio)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cerrar sesión',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.rojoAlerta)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await MockAuthApi.logout();
    if (!context.mounted) return;
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
        automaticallyImplyLeading: false,
        title: Text('Panel de control', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout, color: AppColors.textoClaroMedio),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            // Quién eres
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.azulControl,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_outlined,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.username, style: AppTypography.titleMedium),
                      Text('Administrador del sistema',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textoClaroMedio)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            Text('¿Qué quieres hacer?', style: AppTypography.titleMedium),
            const SizedBox(height: 12),

            _HubCard(
              icon: Icons.storefront_outlined,
              label: 'Entrar a usar la app',
              description: 'Restaurantes, pedidos, inventario y cartera',
              color: AppColors.naranjaAccion,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RestaurantListScreen(user: user)),
              ),
            ),
            _HubCard(
              icon: Icons.manage_accounts_outlined,
              label: 'Administrador de dueños',
              description: 'Clientes, altas y contraseñas',
              color: AppColors.azulControl,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DuenosScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: color.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTypography.titleMedium),
                      const SizedBox(height: 2),
                      Text(description, style: AppTypography.caption),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: AppColors.textoClaroMedio.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
