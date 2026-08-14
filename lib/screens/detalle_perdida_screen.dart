import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';

final _dateFmt = DateFormat('dd MMM yyyy — hh:mm a', 'es');

class DetallePerdidaScreen extends StatelessWidget {
  const DetallePerdidaScreen({
    super.key,
    required this.perdida,
    required this.restaurant,
    required this.user,
  });

  final Perdida    perdida;
  final Restaurant restaurant;
  final AppUser    user;

  @override
  Widget build(BuildContext context) {
    final categ = perdida.categoria.isNotEmpty
        ? perdida.categoria[0].toUpperCase() + perdida.categoria.substring(1)
        : '—';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Detalle de pérdida', style: AppTypography.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Usuario + sucursal
            RestaurantHeader(restaurant: restaurant, user: user),
            const SizedBox(height: 20),

            // Título + categoría + fecha
            Text(perdida.titulo, style: AppTypography.titleLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                _Chip(label: categ, color: AppColors.rojoAlerta),
                const SizedBox(width: 8),
                _Chip(
                  label: _dateFmt.format(perdida.fecha),
                  color: AppColors.azulControl,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Descripción del daño
            _DescripcionCard(texto: perdida.descripcion),
            const SizedBox(height: 24),

            // Tabla de productos dañados
            if (perdida.productos.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Divider(
                        color: AppColors.azulControl.withValues(alpha: 0.3)),
                  ),
                  const SizedBox(width: 10),
                  Text('Productos dañados', style: AppTypography.caption),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Divider(
                        color: AppColors.azulControl.withValues(alpha: 0.3)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              _TableHeader(),
              const SizedBox(height: 4),

              ...perdida.productos.map((p) => _ProductoRow(producto: p)),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Encabezado de tabla
// ---------------------------------------------------------------------------

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.rojoAlerta.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text('Nombre', style: AppTypography.caption)),
          Expanded(
              flex: 2,
              child: Text('Cantidad',
                  style: AppTypography.caption,
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text('UdM',
                  style: AppTypography.caption,
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fila de producto
// ---------------------------------------------------------------------------

class _ProductoRow extends StatelessWidget {
  const _ProductoRow({required this.producto});
  final PerdidaProducto producto;

  @override
  Widget build(BuildContext context) {
    final cantidad = producto.cantidad % 1 == 0
        ? producto.cantidad.toInt().toString()
        : producto.cantidad.toString();
    final unidad = producto.unidad ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: AppColors.azulControl.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(producto.name, style: AppTypography.bodyMedium),
          ),
          Expanded(
            flex: 2,
            child: Text(
              cantidad,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.rojoAlerta),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              unidad.isNotEmpty ? unidad : '—',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textoClaroMedio),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers / widgets internos
// ---------------------------------------------------------------------------

class _DescripcionCard extends StatelessWidget {
  const _DescripcionCard({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.rojoAlerta.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Descripción del daño', style: AppTypography.caption),
            const SizedBox(height: 6),
            Text(
              texto.isNotEmpty ? texto : '—',
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: AppTypography.caption.copyWith(color: color)),
      );
}
