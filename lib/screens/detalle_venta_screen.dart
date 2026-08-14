import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';

class DetalleVentaScreen extends StatelessWidget {
  const DetalleVentaScreen({
    super.key,
    required this.venta,
    required this.restaurant,
    required this.user,
  });

  final Venta      venta;
  final Restaurant restaurant;
  final AppUser    user;

  static final _fmt = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  static final _fechaFmt = DateFormat("dd MMM yyyy · hh:mm a", 'es');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoOscuro,
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Detalle de venta', style: AppTypography.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Usuario + sucursal
            RestaurantHeader(restaurant: restaurant, user: user),
            const SizedBox(height: 16),

            // Encabezado: mesa + orden + fecha
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.verdeExito.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.verdeExito.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6)
                            .withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFF60A5FA)
                                .withValues(alpha: 0.55)),
                      ),
                      child: Text('Orden #${venta.orden}',
                          style: AppTypography.caption.copyWith(
                              color: const Color(0xFF93C5FD),
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Text('Mesa ${venta.mesaNumero}',
                        style: AppTypography.titleMedium
                            .copyWith(color: AppColors.verdeExito)),
                  ]),
                  if (venta.nombreCliente.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.person_outline,
                          size: 14, color: AppColors.textoClaroMedio),
                      const SizedBox(width: 4),
                      Text(venta.nombreCliente,
                          style: AppTypography.caption.copyWith(
                              color: AppColors.textoClaroMedio)),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.schedule,
                        size: 14, color: AppColors.textoClaroMedio),
                    const SizedBox(width: 4),
                    Text(_fechaFmt.format(venta.fecha),
                        style: AppTypography.caption.copyWith(
                            color: AppColors.textoClaroMedio)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Productos vendidos ──────────────────────────────────────
            Text('Productos', style: AppTypography.titleMedium),
            const SizedBox(height: 10),
            ...venta.items.map((it) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.azulControl
                            .withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 30, height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.naranjaAccion
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${it.cantidad}',
                          style: AppTypography.labelLarge.copyWith(
                              color: AppColors.naranjaAccion,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.productoNombre,
                              style: AppTypography.labelLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (it.config.isNotEmpty)
                            Text(it.config,
                                style: AppTypography.caption.copyWith(
                                    color: const Color(0xFF93C5FD),
                                    fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ]),
                )),
            const SizedBox(height: 16),

            // ── Métodos de pago ─────────────────────────────────────────
            Text('Pago', style: AppTypography.titleMedium),
            const SizedBox(height: 10),
            ...venta.pagos.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    const Icon(Icons.payments_outlined,
                        size: 16, color: AppColors.textoClaroMedio),
                    const SizedBox(width: 8),
                    Text(_label(p.metodo),
                        style: AppTypography.bodyMedium),
                    const Spacer(),
                    Text(_fmt.format(p.monto),
                        style: AppTypography.bodyMedium),
                  ]),
                )),
            const SizedBox(height: 10),
            const Divider(color: Color(0xFF334155)),
            const SizedBox(height: 10),

            // Total
            Row(children: [
              Text('Total',
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(_fmt.format(venta.total),
                  style: AppTypography.titleLarge.copyWith(
                      color: AppColors.verdeExito,
                      fontWeight: FontWeight.w700)),
            ]),
          ],
        ),
      ),
    );
  }

  String _label(String m) =>
      m.isEmpty ? m : '${m[0].toUpperCase()}${m.substring(1)}';
}
