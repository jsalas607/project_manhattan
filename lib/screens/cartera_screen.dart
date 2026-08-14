import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';
import 'add_gasto_screen.dart';
import 'add_perdida_screen.dart';
import 'finanzas_screen.dart';

final _currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

class CarteraScreen extends StatefulWidget {
  const CarteraScreen({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser user;

  @override
  State<CarteraScreen> createState() => _CarteraScreenState();
}

class _CarteraScreenState extends State<CarteraScreen> {
  CajaState? _caja;
  DailyStats? _stats;
  List<PaymentMethodTotal> _totales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      MockCarteraApi.getCajaState(widget.restaurant.id),
      MockCarteraApi.getStats(widget.restaurant.id),
      MockCarteraApi.getTotalesPorMetodo(
        widget.restaurant.id,
        widget.restaurant.paymentMethods.isNotEmpty
            ? widget.restaurant.paymentMethods
            : ['efectivo'],
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _caja = results[0] as CajaState;
      _stats = results[1] as DailyStats;
      _totales = results[2] as List<PaymentMethodTotal>;
      _loading = false;
    });
  }

  Future<void> _toggleCaja() async {
    if (_caja?.status == CajaStatus.abierta) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Cerrar caja', style: AppTypography.titleMedium),
          content: Text(
            '¿Seguro que quieres cerrar la caja de hoy?',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: AppTypography.labelLarge.copyWith(color: AppColors.textoClaroMedio)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Cerrar caja', style: AppTypography.labelLarge.copyWith(color: AppColors.rojoAlerta)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await MockCarteraApi.cerrarCaja(widget.restaurant.id);
      if (mounted) _load();
    } else {
      _showAbrirCajaSheet();
    }
  }

  void _showAbrirCajaSheet() {
    final methods = widget.restaurant.paymentMethods.isNotEmpty
        ? widget.restaurant.paymentMethods
        : ['efectivo'];

    final controllers = {
      for (final m in methods) m: TextEditingController(text: '0'),
    };

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final total = controllers.values
              .fold<double>(0, (sum, c) => sum + (double.tryParse(c.text) ?? 0));

          return Padding(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Abrir caja', style: AppTypography.titleLarge),
                const SizedBox(height: 4),
                Text('Ingresa el monto inicial por método de pago',
                    style: AppTypography.bodyMedium),
                const SizedBox(height: 16),

                // Campo por cada método de pago
                ...methods.map((m) {
                  final label =
                      m[0].toUpperCase() + m.substring(1);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[m],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      style: AppTypography.bodyLarge,
                      cursorColor: AppColors.naranjaAccion,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        labelText: '$label (\$)',
                        labelStyle: AppTypography.bodyMedium,
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.naranjaAccion, width: 1.5),
                        ),
                      ),
                    ),
                  );
                }),

                // Cuadro de total
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.naranjaAccion.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.naranjaAccion.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total en caja', style: AppTypography.labelLarge),
                      Text(
                        _currencyFmt.format(total),
                        style: AppTypography.titleMedium
                            .copyWith(color: AppColors.naranjaAccion),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: () async {
                    final montos = {
                      for (final m in methods)
                        m: double.tryParse(controllers[m]!.text) ?? 0,
                    };
                    await MockCarteraApi.abrirCaja(
                        widget.restaurant.id, montos);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _load();
                  },
                  child: const Text('Abrir caja'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddGasto() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddGastoScreen(
          restaurant: widget.restaurant,
          user: widget.user,
        ),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _showAddPerdida() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddPerdidaScreen(
          restaurant: widget.restaurant,
          user: widget.user,
        ),
      ),
    );
    if (result == true) _load();
  }


  @override
  Widget build(BuildContext context) {
    final isAbierta = _caja?.status == CajaStatus.abierta;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Cartera', style: AppTypography.titleLarge),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.naranjaAccion))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Usuario + sucursal
                  RestaurantHeader(
                      restaurant: widget.restaurant, user: widget.user),
                  const SizedBox(height: 16),

                  // Botón iniciar/cerrar caja
                  ElevatedButton.icon(
                    onPressed: _toggleCaja,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAbierta ? AppColors.rojoAlerta : AppColors.verdeExito,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: Icon(isAbierta ? Icons.lock : Icons.lock_open, size: 20),
                    label: Text(isAbierta ? 'Cerrar caja' : 'Iniciar caja'),
                  ),
                  if (isAbierta && _caja?.abiertaEn != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Abierta desde ${DateFormat('hh:mm a').format(_caja!.abiertaEn!)}  •  Monto inicial: ${_currencyFmt.format(_caja!.montoTotal)}',
                      style: AppTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Totales por método de pago
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2,
                    ),
                    itemCount: _totales.length,
                    itemBuilder: (_, i) => _PaymentCard(total: _totales[i]),
                  ),
                  const SizedBox(height: 16),

                  // Estadísticas del día
                  if (_stats != null) _StatsCard(stats: _stats!),
                  const SizedBox(height: 16),

                  // Añadir gastos / pérdidas
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.remove_circle_outline,
                          label: 'Añadir gasto',
                          color: AppColors.naranjaAccion,
                          onTap: _showAddGasto,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.warning_amber_outlined,
                          label: 'Añadir pérdida',
                          color: AppColors.rojoAlerta,
                          onTap: _showAddPerdida,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Finanzas
                  _ActionCard(
                    icon: Icons.bar_chart,
                    label: 'Finanzas',
                    color: AppColors.azulControl,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FinanzasScreen(
                          restaurant: widget.restaurant,
                          user: widget.user,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets internos
// ---------------------------------------------------------------------------

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.total});
  final PaymentMethodTotal total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.verdeExito.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            total.name[0].toUpperCase() + total.name.substring(1),
            style: AppTypography.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            _currencyFmt.format(total.total),
            style: AppTypography.titleMedium.copyWith(color: AppColors.verdeExito),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final DailyStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.azulControl.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estadísticas del día', style: AppTypography.titleMedium),
          const SizedBox(height: 12),
          _StatRow('Órdenes creadas',            '${stats.ordenesCreadias}'),
          _StatRow('Dinero facturado',            _currencyFmt.format(stats.dineroFacturado)),
          _StatRow('Promedio por orden',          _currencyFmt.format(stats.promedioOrden)),
          _StatRow('Gastos del día',              _currencyFmt.format(stats.gastosDia), color: AppColors.naranjaAccion),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium),
          Text(
            value,
            style: AppTypography.labelLarge.copyWith(
              color: color ?? AppColors.textoClaroAlto,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: AppTypography.labelLarge.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

