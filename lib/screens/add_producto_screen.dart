import 'package:flutter/material.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';
import 'add_producto_compuesto_screen.dart';
import 'add_producto_unitario_screen.dart';

class AddProductoScreen extends StatelessWidget {
  const AddProductoScreen({
    super.key,
    required this.restaurant,
    required this.user,
    required this.onAdded,
  });

  final Restaurant             restaurant;
  final AppUser                user;
  final void Function(Producto) onAdded;

  void _proximamente(BuildContext context, String tipo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text('Próximamente: formulario $tipo'),
        duration:        const Duration(seconds: 1),
        backgroundColor: AppColors.azulControl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoOscuro,
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Añadir producto', style: AppTypography.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Usuario + sucursal ─────────────────────────────────────────
            RestaurantHeader(restaurant: restaurant, user: user),
            const SizedBox(height: 32),

            // ── Instrucción ────────────────────────────────────────────────
            Text('¿Qué tipo de producto es?',
                style: AppTypography.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Selecciona el tipo antes de continuar.',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textoClaroMedio),
            ),
            const SizedBox(height: 20),

            // ── Dos tarjetas ───────────────────────────────────────────────
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Producto unitario
                  Expanded(
                    child: _TipoCard(
                      icon:        Icons.inventory_2_outlined,
                      titulo:      'Producto\nunitario',
                      descripcion: 'Cerveza, agua,\nrefresco, postre...',
                      color:       AppColors.azulControl,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddProductoUnitarioScreen(
                            restaurant: restaurant,
                            user:       user,
                            onAdded:    onAdded,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Producto compuesto
                  Expanded(
                    child: _TipoCard(
                      icon:        Icons.restaurant_menu,
                      titulo:      'Producto\ncompuesto',
                      descripcion: 'Hamburguesa,\nalmuerzo, arepa...',
                      color:       AppColors.naranjaAccion,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddProductoCompuestoScreen(
                            restaurant: restaurant,
                            user:       user,
                            onAdded:    onAdded,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Nota informativa ───────────────────────────────────────────
            _NotaCard(
              children: [
                _NotaFila(
                  icon:  Icons.inventory_2_outlined,
                  color: AppColors.azulControl,
                  texto:
                      'Unitario: se vende tal cual, sin fabricación. Ej: una lata de cerveza, una botella de agua.',
                ),
                const SizedBox(height: 10),
                _NotaFila(
                  icon:  Icons.restaurant_menu,
                  color: AppColors.naranjaAccion,
                  texto:
                      'Compuesto: requiere ingredientes para elaborarse. Ej: hamburguesa, almuerzo, arepa con queso.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de tipo de producto
// ---------------------------------------------------------------------------

class _TipoCard extends StatelessWidget {
  const _TipoCard({
    required this.icon,
    required this.titulo,
    required this.descripcion,
    required this.color,
    required this.onTap,
  });

  final IconData     icon;
  final String       titulo;
  final String       descripcion;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícono
              Container(
                width:  60,
                height: 60,
                decoration: BoxDecoration(
                  color:        color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),

              // Título
              Text(
                titulo,
                style: AppTypography.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Descripción
              Text(
                descripcion,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textoClaroMedio),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Botón "Seleccionar"
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color:        color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Seleccionar',
                  style: AppTypography.caption
                      .copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nota informativa
// ---------------------------------------------------------------------------

class _NotaCard extends StatelessWidget {
  const _NotaCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.azulControl.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.textoClaroMedio, size: 16),
                const SizedBox(width: 6),
                Text('¿Cuál es la diferencia?',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.textoClaroMedio,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
}

class _NotaFila extends StatelessWidget {
  const _NotaFila({
    required this.icon,
    required this.color,
    required this.texto,
  });
  final IconData icon;
  final Color    color;
  final String   texto;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textoClaroMedio)),
          ),
        ],
      );
}

