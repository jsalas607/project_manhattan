import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';
import 'detalle_gasto_screen.dart';
import 'detalle_perdida_screen.dart';
import 'detalle_venta_screen.dart';

final _currencyFmt = NumberFormat.currency(
    locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _dateFmt = DateFormat('dd MMM yyyy', 'es');

// ---------------------------------------------------------------------------
// Tipo unificado para mezclar gastos y pérdidas en una sola lista
// ---------------------------------------------------------------------------

abstract class _FItem {
  DateTime get fecha;
}

class _FGasto extends _FItem {
  _FGasto(this.data);
  final Gasto data;
  @override
  DateTime get fecha => data.fecha;
}

class _FPerdida extends _FItem {
  _FPerdida(this.data);
  final Perdida data;
  @override
  DateTime get fecha => data.fecha;
}

class _FVenta extends _FItem {
  _FVenta(this.data);
  final Venta data;
  @override
  DateTime get fecha => data.fecha;
}

// ---------------------------------------------------------------------------

class FinanzasScreen extends StatefulWidget {
  const FinanzasScreen({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser    user;

  @override
  State<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends State<FinanzasScreen> {
  // Filtros activos (toggle independiente)
  bool _showVentas   = true;
  bool _showGastos   = true;
  bool _showPerdidas = true;

  DateTimeRange? _rangoFechas;
  bool           _loading = true;

  List<Venta>   _ventas   = [];
  List<Gasto>   _gastos   = [];
  List<Perdida> _perdidas = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final v = await MockVentasApi.getVentas(widget.restaurant.id);
    final g = await MockCarteraApi.getGastos(widget.restaurant.id);
    final p = await MockCarteraApi.getPerdidas(widget.restaurant.id);
    if (!mounted) return;
    setState(() {
      _ventas   = v;
      _gastos   = g;
      _perdidas = p;
      _loading  = false;
    });
  }

  // ── Filtros de fecha ──────────────────────────────────────────────────────

  List<Venta> get _ventasFiltradas {
    if (_rangoFechas == null) return _ventas;
    return _ventas.where((v) => _enRango(v.fecha)).toList();
  }

  List<Gasto> get _gastosFiltrados {
    if (_rangoFechas == null) return _gastos;
    return _gastos.where((g) => _enRango(g.fecha)).toList();
  }

  List<Perdida> get _perdidasFiltradas {
    if (_rangoFechas == null) return _perdidas;
    return _perdidas.where((p) => _enRango(p.fecha)).toList();
  }

  bool _enRango(DateTime fecha) {
    final d     = DateTime(fecha.year, fecha.month, fecha.day);
    final start = DateTime(_rangoFechas!.start.year,
        _rangoFechas!.start.month, _rangoFechas!.start.day);
    final end   = DateTime(_rangoFechas!.end.year,
        _rangoFechas!.end.month, _rangoFechas!.end.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  // ── Lista combinada y ordenada ────────────────────────────────────────────

  List<_FItem> get _itemsFiltrados {
    final list = <_FItem>[];
    if (_showVentas)   list.addAll(_ventasFiltradas.map(_FVenta.new));
    if (_showGastos)   list.addAll(_gastosFiltrados.map(_FGasto.new));
    if (_showPerdidas) list.addAll(_perdidasFiltradas.map(_FPerdida.new));
    list.sort((a, b) => b.fecha.compareTo(a.fecha));
    return list;
  }

  // ── Totales ───────────────────────────────────────────────────────────────

  double get _totalVentas =>
      _ventasFiltradas.fold(0.0, (s, v) => s + v.total);

  double get _totalGastos =>
      _gastosFiltrados.fold(0, (s, g) => s + g.monto);

  String get _resumenPerdidas {
    final n = _perdidasFiltradas.length;
    return '$n ${n == 1 ? "registro" : "registros"}';
  }

  // ── Fecha ─────────────────────────────────────────────────────────────────

  Future<void> _pickFecha() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate:  DateTime.now(),
      initialDateRange: _rangoFechas,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   AppColors.naranjaAccion,
            onPrimary: AppColors.textoClaroAlto,
            surface:   Color(0xFF1E293B),
            onSurface: AppColors.textoClaroAlto,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _rangoFechas = picked);
  }

  void _limpiarFecha() => setState(() => _rangoFechas = null);

  bool _mismaFechaRange(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Finanzas', style: AppTypography.titleLarge),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.naranjaAccion))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Usuario + sucursal
                      RestaurantHeader(
                          restaurant: widget.restaurant, user: widget.user),
                      const SizedBox(height: 16),

                      // ── Chips de filtro (multi-selección) ──────────────
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label:       'Ventas',
                              active:      _showVentas,
                              activeColor: AppColors.verdeExito,
                              onTap: () =>
                                  setState(() => _showVentas = !_showVentas),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label:       'Gastos',
                              active:      _showGastos,
                              activeColor: AppColors.naranjaAccion,
                              onTap: () =>
                                  setState(() => _showGastos = !_showGastos),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label:       'Pérdidas',
                              active:      _showPerdidas,
                              activeColor: AppColors.rojoAlerta,
                              onTap: () =>
                                  setState(() => _showPerdidas = !_showPerdidas),
                            ),
                            const SizedBox(width: 12),

                            // Fecha / Rango
                            GestureDetector(
                              onTap: _pickFecha,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _rangoFechas != null
                                      ? AppColors.naranjaAccion
                                          .withValues(alpha: 0.15)
                                      : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _rangoFechas != null
                                        ? AppColors.naranjaAccion
                                        : AppColors.azulControl
                                            .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        size: 14,
                                        color: _rangoFechas != null
                                            ? AppColors.naranjaAccion
                                            : AppColors.textoClaroMedio),
                                    const SizedBox(width: 6),
                                    Text(
                                      _rangoFechas == null
                                          ? 'Fecha'
                                          : _mismaFechaRange(
                                                  _rangoFechas!.start,
                                                  _rangoFechas!.end)
                                              ? _dateFmt.format(
                                                  _rangoFechas!.start)
                                              : '${_dateFmt.format(_rangoFechas!.start)} — ${_dateFmt.format(_rangoFechas!.end)}',
                                      style: AppTypography.caption.copyWith(
                                        color: _rangoFechas != null
                                            ? AppColors.naranjaAccion
                                            : AppColors.textoClaroMedio,
                                      ),
                                    ),
                                    if (_rangoFechas != null) ...[
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: _limpiarFecha,
                                        child: const Icon(Icons.close,
                                            size: 14,
                                            color: AppColors.naranjaAccion),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Resumen dinámico ────────────────────────────────
                      _buildResumen(),
                      const SizedBox(height: 8),

                      // ── Encabezado tabla ────────────────────────────────
                      _TableHeader(
                        showVentas:   _showVentas,
                        showGastos:   _showGastos,
                        showPerdidas: _showPerdidas,
                      ),
                    ],
                  ),
                ),

                // ── Lista combinada ───────────────────────────────────────
                Expanded(
                  child: _ListaCombinada(
                    items:      _itemsFiltrados,
                    restaurant: widget.restaurant,
                    user:       widget.user,
                  ),
                ),
              ],
            ),
    );
  }

  // Muestra totales adaptados a los filtros activos (tarjetas compactas)
  Widget _buildResumen() {
    if (!_showVentas && !_showGastos && !_showPerdidas) {
      return Center(
        child: Text('Sin filtros activos',
            style: AppTypography.caption
                .copyWith(color: AppColors.textoClaroMedio)),
      );
    }

    final tarjetas = <Widget>[
      if (_showVentas)
        _ResumenBox(
          label: 'Ventas',
          valor: _currencyFmt.format(_totalVentas),
          color: AppColors.verdeExito,
        ),
      if (_showGastos)
        _ResumenBox(
          label: 'Gastos',
          valor: _currencyFmt.format(_totalGastos),
          color: AppColors.naranjaAccion,
        ),
      if (_showPerdidas)
        _ResumenBox(
          label: 'Pérdidas',
          valor: _resumenPerdidas,
          color: AppColors.rojoAlerta,
        ),
    ];

    // Intercalar separadores entre tarjetas
    final children = <Widget>[];
    for (var i = 0; i < tarjetas.length; i++) {
      children.add(Expanded(child: tarjetas[i]));
      if (i < tarjetas.length - 1) children.add(const SizedBox(width: 10));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

// ---------------------------------------------------------------------------
// Caja de resumen (label + valor coloreado)
// ---------------------------------------------------------------------------

class _ResumenBox extends StatelessWidget {
  const _ResumenBox({
    required this.label,
    required this.valor,
    required this.color,
  });

  final String label;
  final String valor;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption),
          const SizedBox(height: 2),
          Text(valor,
              style: AppTypography.titleMedium.copyWith(
                  color: color, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lista combinada (gastos + pérdidas mezclados, ordenados por fecha)
// ---------------------------------------------------------------------------

class _ListaCombinada extends StatelessWidget {
  const _ListaCombinada({
    required this.items,
    required this.restaurant,
    required this.user,
  });

  final List<_FItem> items;
  final Restaurant   restaurant;
  final AppUser      user;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Sin registros',
          style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textoClaroMedio.withValues(alpha: 0.5)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, i) => Divider(
          color: AppColors.azulControl.withValues(alpha: 0.25), height: 1),
      itemBuilder: (_, i) {
        final item = items[i];

        if (item is _FVenta) {
          final v = item.data;
          return _RowItem(
            categ:        'Mesa ${v.mesaNumero}',
            nombre:       v.nombreCliente.isEmpty
                ? 'Orden #${v.orden}'
                : v.nombreCliente,
            montoDisplay: _currencyFmt.format(v.total),
            fecha:        v.fecha,
            color:        AppColors.verdeExito,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetalleVentaScreen(
                  venta:      v,
                  restaurant: restaurant,
                  user:       user,
                ),
              ),
            ),
          );
        }

        if (item is _FGasto) {
          final g = item.data;
          return _RowItem(
            categ:        g.metodoPago,
            nombre:       g.descripcion,
            montoDisplay: _currencyFmt.format(g.monto),
            fecha:        g.fecha,
            color:        AppColors.naranjaAccion,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetalleGastoScreen(
                  gasto:      g,
                  restaurant: restaurant,
                  user:       user,
                ),
              ),
            ),
          );
        }

        final p = (item as _FPerdida).data;
        return _RowItem(
          categ:        p.categoria,
          nombre:       p.titulo,
          montoDisplay: _cantidadPerdida(p),
          fecha:        p.fecha,
          color:        AppColors.rojoAlerta,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetallePerdidaScreen(
                perdida:    p,
                restaurant: restaurant,
                user:       user,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Helper: formatea la cantidad de productos de una pérdida
// ---------------------------------------------------------------------------

String _cantidadPerdida(Perdida p) {
  if (p.productos.isEmpty) return '—';
  if (p.productos.length == 1) {
    final prod = p.productos.first;
    final qty  = prod.cantidad % 1 == 0
        ? prod.cantidad.toInt().toString()
        : prod.cantidad.toString();
    final u = prod.unidad ?? '';
    return u.isNotEmpty ? '$qty $u' : qty;
  }
  return p.productos.map((prod) {
    final qty = prod.cantidad % 1 == 0
        ? prod.cantidad.toInt().toString()
        : prod.cantidad.toString();
    final u = prod.unidad ?? '';
    return u.isNotEmpty ? '$qty $u' : qty;
  }).join(' · ');
}

// ---------------------------------------------------------------------------
// Fila de tabla
// ---------------------------------------------------------------------------

class _RowItem extends StatelessWidget {
  const _RowItem({
    required this.categ,
    required this.nombre,
    required this.montoDisplay,
    required this.fecha,
    required this.color,
    required this.onTap,
  });

  final String       categ;
  final String       nombre;
  final String       montoDisplay;
  final DateTime     fecha;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = categ.isNotEmpty
        ? categ[0].toUpperCase() + categ.substring(1)
        : '—';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: AppTypography.caption.copyWith(color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre,
                      style: AppTypography.bodyMedium,
                      overflow: TextOverflow.ellipsis),
                  Text(_dateFmt.format(fecha), style: AppTypography.caption),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(montoDisplay,
                style: AppTypography.labelLarge.copyWith(color: color)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios,
                size: 12, color: AppColors.textoClaroMedio),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Encabezado de tabla (se adapta a los filtros activos)
// ---------------------------------------------------------------------------

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.showVentas,
    required this.showGastos,
    required this.showPerdidas,
  });

  final bool showVentas;
  final bool showGastos;
  final bool showPerdidas;

  @override
  Widget build(BuildContext context) {
    // Cuántos filtros activos
    final activos =
        (showVentas ? 1 : 0) + (showGastos ? 1 : 0) + (showPerdidas ? 1 : 0);
    final unico = activos == 1;

    String categLabel = 'Tipo';
    String nameLabel  = 'Nombre';
    String valueLabel = 'Valor';
    if (unico) {
      if (showVentas) {
        categLabel = 'Mesa';   nameLabel = 'Cliente';     valueLabel = 'Total';
      } else if (showGastos) {
        categLabel = 'Método pago'; nameLabel = 'Descripción'; valueLabel = 'Monto';
      } else {
        categLabel = 'Categoría';   nameLabel = 'Título';      valueLabel = 'Cantidad';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: AppColors.azulControl.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 90,
              child: Text(categLabel, style: AppTypography.caption)),
          const SizedBox(width: 10),
          Expanded(child: Text(nameLabel, style: AppTypography.caption)),
          const SizedBox(width: 10),
          Text(valueLabel, style: AppTypography.caption),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip de filtro (toggle)
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final String       label;
  final bool         active;
  final Color        activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? activeColor
                : AppColors.azulControl.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: active
                ? AppColors.textoClaroAlto
                : AppColors.textoClaroMedio,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers / widgets internos
// ---------------------------------------------------------------------------

