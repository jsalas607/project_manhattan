import 'package:flutter/material.dart';

import '../core/app_design_system.dart';
import 'login_screen.dart';

/// Pantalla temporal post-selección de restaurante.
/// Se reemplazará por el flujo real (crear orden, dashboard, etc.).
class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key, required this.restaurantName});

  final String restaurantName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        title: Text(restaurantName, style: AppTypography.titleLarge),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.store,
                  color: AppColors.verdeExito,
                  size: 72,
                ),
                const SizedBox(height: 16),
                Text(restaurantName, style: AppTypography.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  'Aquí irá el dashboard / crear orden.',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Volver'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  },
                  child: Text(
                    'Cerrar sesión',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.rojoAlerta,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
