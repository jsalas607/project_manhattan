import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';

/// Detalle de un producto del menú: muestra su información y permite
/// eliminarlo del menú (lista de productos). NO afecta el inventario.
class ProductoDetalleScreen extends StatefulWidget {
  const ProductoDetalleScreen({
    super.key,
    required this.restaurant,
    required this.user,
    required this.producto,
    required this.categoriaNombre,
  });

  final Restaurant restaurant;
  final AppUser    user;
  final Producto   producto;
  final String     categoriaNombre;

  @override
  State<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen> {
  bool _deleting = false;

  final _fmt = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  Producto get _p => widget.producto;

  Future<void> _confirmarEliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Eliminar del menú', style: AppTypography.titleMedium),
        content: Text(
          'Se eliminará «${_p.nombre}» del menú.\n\n'
          'Tu inventario no se verá afectado.',
          style: AppTypography.bodyMedium
              .copyWith(color: AppColors.textoClaroMedio),
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
            child: Text('Eliminar',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.rojoAlerta)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _deleting = true);
    try {
      await MockMenuApi.deleteProducto(widget.restaurant.id, _p.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $e'),
          backgroundColor: AppColors.rojoAlerta,
        ),
      );
    }
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
        title: Text('Detalle del producto', style: AppTypography.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RestaurantHeader(restaurant: widget.restaurant, user: widget.user),
            const SizedBox(height: 20),

            // Tarjeta principal del producto
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.azulControl.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Foto (placeholder)
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.azulControl.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.azulControl
                                  .withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.image_outlined,
                            color: AppColors.textoClaroMedio, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_p.nombre, style: AppTypography.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              _fmt.format(_p.precio),
                              style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.naranjaAccion,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFF334155)),
                  const SizedBox(height: 12),

                  _InfoRow(label: 'Categoría', value: widget.categoriaNombre),
                  _InfoRow(
                    label: 'Estado',
                    value: _p.visible ? 'Visible' : 'Oculto',
                    valueColor: _p.visible
                        ? AppColors.verdeExito
                        : AppColors.textoClaroMedio,
                  ),
                  _InfoRow(
                    label: 'Producto',
                    value: _p.esCompuesto ? 'Compuesto' : 'Unitario',
                  ),
                ],
              ),
            ),

            // Receta (solo compuestos)
            if (_p.esCompuesto) ...[
              const SizedBox(height: 20),
              Text('Receta', style: AppTypography.titleMedium),
              const SizedBox(height: 10),
              ..._p.ingredientes.map((ing) => _IngredienteCard(ing: ing)),
            ],

            const SizedBox(height: 28),

            // Eliminar del menú
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _deleting ? null : _confirmarEliminar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rojoAlerta,
                  disabledBackgroundColor:
                      AppColors.rojoAlerta.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.delete_outline,
                        color: Colors.white, size: 20),
                label: Text(
                  _deleting ? 'Eliminando…' : 'Eliminar del menú',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.textoClaroAlto),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Esto solo lo quita del menú. No afecta tu inventario.',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textoClaroMedio),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets internos
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textoClaroMedio)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium
                  .copyWith(color: valueColor ?? AppColors.textoClaroAlto),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredienteCard extends StatelessWidget {
  const _IngredienteCard({required this.ing});
  final IngredienteReceta ing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.azulControl.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(ing.nombre, style: AppTypography.labelLarge),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (ing.obligatorio
                          ? AppColors.naranjaAccion
                          : AppColors.azulControl)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ing.obligatorio ? 'Obligatorio' : 'Opcional',
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    color: ing.obligatorio
                        ? AppColors.naranjaAccion
                        : AppColors.azulControl,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ing.opciones
                .map((o) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(o.nombre,
                          style: AppTypography.caption.copyWith(
                              color: AppColors.textoClaroMedio)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
