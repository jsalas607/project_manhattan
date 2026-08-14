import 'package:flutter/material.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../screens/profile_screen.dart';

/// Encabezado compartido de las pantallas internas:
/// chip de usuario (avatar + nombre + rol) a la izquierda y nombre de la
/// sucursal a la derecha, en una sola fila para optimizar espacio vertical.
/// Tocar el chip de usuario abre el Perfil (donde está "Cerrar sesión").
class RestaurantHeader extends StatelessWidget {
  const RestaurantHeader({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser    user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Chip de usuario (tocar → Perfil)
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.azulControl,
                child: Icon(Icons.person,
                    size: 20, color: AppColors.textoClaroAlto),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(user.username, style: AppTypography.labelLarge),
                  Text(
                    user.role,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textoClaroMedio),
                  ),
                ],
              ),
            ],
          ),
          ),
        ),
        const SizedBox(width: 14),

        // Nombre de la sucursal (texto plano, sin caja)
        Expanded(
          child: Text(
            restaurant.title,
            style: AppTypography.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
