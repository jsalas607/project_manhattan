import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';

class CobrarMesaScreen extends StatefulWidget {
  const CobrarMesaScreen({
    super.key,
    required this.mesa,
    required this.restaurant,
    required this.user,
    required this.items,
    required this.total,
  });

  final Mesa             mesa;
  final Restaurant       restaurant;
  final AppUser          user;
  final List<ItemPedido> items;
  final double           total;

  @override
  State<CobrarMesaScreen> createState() => _CobrarMesaScreenState();
}

class _CobrarMesaScreenState extends State<CobrarMesaScreen> {
  static final _fmt = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  // Métodos seleccionados → controlador del monto de cada uno
  final Map<String, TextEditingController> _montos = {};
  bool _cobrando = false;
  bool _intento  = false;

  @override
  void dispose() {
    for (final c in _montos.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _metodos => widget.restaurant.paymentMethods;

  bool _activo(String metodo) => _montos.containsKey(metodo);

  void _toggleMetodo(String metodo) {
    setState(() {
      if (_montos.containsKey(metodo)) {
        _montos.remove(metodo)!.dispose();
      } else {
        // El monto lo escribe el cajero manualmente (sin autocompletar)
        _montos[metodo] = TextEditingController();
      }
    });
  }

  /// Convierte el texto del campo (con puntos de miles) a número.
  double _parseMonto(String texto) =>
      double.tryParse(texto.replaceAll('.', '').trim()) ?? 0;

  double get _sumaIngresada {
    var suma = 0.0;
    for (final c in _montos.values) {
      suma += _parseMonto(c.text);
    }
    return suma;
  }

  double get _restante => widget.total - _sumaIngresada;

  /// Cambio a devolver al cliente (cuando paga de más).
  double get _cambio => _sumaIngresada - widget.total;

  /// Pagos "normalizados" a la caja: recorta el exceso para que la suma sea
  /// exactamente el total de la cuenta. Recorre los métodos en orden y a cada
  /// uno le asigna lo que falte hasta cubrir el total (el resto es cambio).
  /// Así la caja nunca se infla cuando el cliente paga de más.
  List<PagoMetodo> _pagosNormalizados() {
    var restante = widget.total;
    final pagos = <PagoMetodo>[];
    for (final e in _montos.entries) {
      if (restante <= 0) break;
      final tecleado = _parseMonto(e.value.text);
      final aplicado = tecleado < restante ? tecleado : restante;
      if (aplicado > 0) {
        pagos.add(PagoMetodo(metodo: e.key, monto: aplicado));
        restante -= aplicado;
      }
    }
    return pagos;
  }

  /// Se puede cobrar si ingresó algo y el pago cubre el total
  /// (exacto o de más). Solo se bloquea cuando FALTA dinero.
  bool get _puedeCobrar =>
      _montos.isNotEmpty && _restante <= 0.5; // tolerancia de redondeo

  /// Diálogo que muestra el cambio a devolver antes de confirmar el cobro.
  Future<bool?> _confirmarCambio() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width:  40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.naranjaAccion.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.currency_exchange,
                color: AppColors.naranjaAccion, size: 22),
          ),
          const SizedBox(width: 12),
          Text('Devolver cambio', style: AppTypography.titleMedium),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LineaResumen(
                label: 'Total de la cuenta',
                valor: _fmt.format(widget.total)),
            const SizedBox(height: 8),
            _LineaResumen(
                label: 'Pagó el cliente',
                valor: _fmt.format(_sumaIngresada)),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFF334155)),
            const SizedBox(height: 12),
            // Cambio destacado
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.naranjaAccion.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.naranjaAccion
                        .withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                Text('Cambio a devolver',
                    style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(_fmt.format(_cambio),
                    style: AppTypography.titleLarge.copyWith(
                        color: AppColors.naranjaAccion,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
        ),
        actionsPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.textoClaroMedio)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verdeExito,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 12),
              elevation: 0,
            ),
            child: Text('Confirmar cobro',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.textoClaroAlto)),
          ),
        ],
      ),
    );
  }

  Future<void> _cobrar() async {
    setState(() => _intento = true);
    if (!_puedeCobrar) return;

    // Si el cliente pagó de más, confirmar el cambio a devolver
    if (_cambio > 0.5) {
      final ok = await _confirmarCambio();
      if (ok != true) return;
    }

    setState(() => _cobrando = true);

    // Pagos recortados al total real → la caja no se infla con el cambio
    final pagos = _pagosNormalizados();

    // 1. Registrar la venta en la base de datos del día
    await MockVentasApi.registrarVenta(
      widget.restaurant.id,
      mesaNumero:    widget.mesa.numero,
      orden:         widget.mesa.orden,
      nombreCliente: widget.mesa.nombre,
      items:         widget.items,
      pagos:         pagos,
      total:         widget.total,
    );
    // 2. Eliminar el pedido (sale de despachar)
    await MockPedidosApi.eliminarPedido(
        widget.restaurant.id, widget.mesa.id);
    // 3. Eliminar la mesa (sale de atender mesa)
    await MockAtenderMesaApi.removeMesa(
        widget.restaurant.id, widget.mesa.id);

    if (!mounted) return;
    // Devuelve true → la mesa fue cobrada
    Navigator.pop(context, true);
  }

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
        title: Text('Cobrar — Mesa ${widget.mesa.numero}',
            style: AppTypography.titleLarge),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info mesa / cliente
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.azulControl
                              .withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6)
                              .withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF60A5FA)
                                  .withValues(alpha: 0.55)),
                        ),
                        child: Text('Orden #${widget.mesa.orden}',
                            style: AppTypography.caption.copyWith(
                                color: const Color(0xFF93C5FD),
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Text('Mesa ${widget.mesa.numero}',
                          style: AppTypography.titleMedium),
                      if (widget.mesa.nombre.isNotEmpty) ...[
                        const Spacer(),
                        const Icon(Icons.person_outline,
                            size: 14,
                            color: AppColors.textoClaroMedio),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(widget.mesa.nombre,
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.textoClaroMedio),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // ── Resumen de la orden ──────────────────────────────────
                  Text('Resumen de la orden',
                      style: AppTypography.titleMedium),
                  const SizedBox(height: 10),
                  ...widget.items.map((it) => _ResumenItemRow(
                      item: it, fmt: _fmt, total: widget.total)),
                  const SizedBox(height: 10),
                  const Divider(color: Color(0xFF334155)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('Total a cobrar',
                        style: AppTypography.titleMedium
                            .copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(_fmt.format(widget.total),
                        style: AppTypography.titleLarge.copyWith(
                            color: AppColors.naranjaAccion,
                            fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 24),

                  // ── Métodos de pago ──────────────────────────────────────
                  Text('Métodos de pago',
                      style: AppTypography.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Selecciona uno o varios. La suma debe igualar el total.',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textoClaroMedio),
                  ),
                  const SizedBox(height: 12),

                  if (_metodos.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.rojoAlerta.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.rojoAlerta
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Este restaurante no tiene métodos de pago configurados.',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.rojoAlerta),
                      ),
                    )
                  else
                    ..._metodos.map((m) => _MetodoPagoTile(
                          metodo:  m,
                          activo:  _activo(m),
                          ctrl:    _montos[m],
                          onToggle: () => _toggleMetodo(m),
                          onChanged: () => setState(() {}),
                        )),

                  if (_intento && _montos.isEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Selecciona al menos un método de pago',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.rojoAlerta)),
                  ],
                ],
              ),
            ),
          ),

          // ── Barra inferior: restante + botón cobrar ──────────────────────
          _BarraInferior(
            total:        widget.total,
            ingresado:    _sumaIngresada,
            restante:     _restante,
            puedeCobrar:  _puedeCobrar,
            cobrando:     _cobrando,
            fmt:          _fmt,
            onCobrar:     _cobrar,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fila del resumen de la orden
// ---------------------------------------------------------------------------

class _ResumenItemRow extends StatelessWidget {
  const _ResumenItemRow({
    required this.item,
    required this.fmt,
    required this.total,
  });

  final ItemPedido   item;
  final NumberFormat fmt;
  final double       total;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.azulControl.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width:  30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.naranjaAccion.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('${item.cantidad}',
              style: AppTypography.labelLarge.copyWith(
                  color: AppColors.naranjaAccion,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.productoNombre,
                  style: AppTypography.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (item.config.isNotEmpty)
                Text(item.config,
                    style: AppTypography.caption.copyWith(
                        color: const Color(0xFF93C5FD),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile de método de pago (seleccionable + monto)
// ---------------------------------------------------------------------------

class _MetodoPagoTile extends StatelessWidget {
  const _MetodoPagoTile({
    required this.metodo,
    required this.activo,
    required this.ctrl,
    required this.onToggle,
    required this.onChanged,
  });

  final String                  metodo;
  final bool                    activo;
  final TextEditingController?  ctrl;
  final VoidCallback            onToggle;
  final VoidCallback            onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: activo
            ? AppColors.verdeExito.withValues(alpha: 0.06)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activo
              ? AppColors.verdeExito.withValues(alpha: 0.5)
              : AppColors.azulControl.withValues(alpha: 0.25),
          width: activo ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header: checkbox + nombre del método
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  width:  22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activo
                        ? AppColors.verdeExito
                        : Colors.transparent,
                    border: Border.all(
                      color: activo
                          ? AppColors.verdeExito
                          : AppColors.textoClaroMedio
                              .withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: activo
                      ? const Icon(Icons.check,
                          size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  _label(metodo),
                  style: AppTypography.bodyMedium.copyWith(
                    color: activo
                        ? AppColors.textoClaroAlto
                        : AppColors.textoClaroMedio,
                    fontWeight:
                        activo ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ]),
            ),
          ),
          // Campo de monto (solo si está activo)
          if (activo)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: TextField(
                controller: ctrl,
                onChanged:  (_) => onChanged(),
                keyboardType: TextInputType.number,
                inputFormatters: [_MilesInputFormatter()],
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: AppTypography.bodyMedium
                      .copyWith(color: AppColors.naranjaAccion),
                  hintText: 'Monto en $metodo',
                  hintStyle: AppTypography.caption.copyWith(
                      color: AppColors.textoClaroMedio
                          .withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: AppColors.azulControl
                            .withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.naranjaAccion),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _label(String m) =>
      m.isEmpty ? m : '${m[0].toUpperCase()}${m.substring(1)}';
}

// ---------------------------------------------------------------------------
// Barra inferior con restante + botón cobrar
// ---------------------------------------------------------------------------

class _BarraInferior extends StatelessWidget {
  const _BarraInferior({
    required this.total,
    required this.ingresado,
    required this.restante,
    required this.puedeCobrar,
    required this.cobrando,
    required this.fmt,
    required this.onCobrar,
  });

  final double       total;
  final double       ingresado;
  final double       restante;
  final bool         puedeCobrar;
  final bool         cobrando;
  final NumberFormat fmt;
  final VoidCallback onCobrar;

  @override
  Widget build(BuildContext context) {
    // Mensaje de estado del restante
    final Color  estadoColor;
    final String estadoTexto;
    if (restante.abs() < 0.5) {
      estadoColor = AppColors.verdeExito;
      estadoTexto = 'Pago completo';
    } else if (restante > 0) {
      // Falta dinero → bloquea el cobro
      estadoColor = AppColors.naranjaAccion;
      estadoTexto = 'Falta ${fmt.format(restante)}';
    } else {
      // Paga de más → cambio a devolver (no es error, permite cobrar)
      estadoColor = const Color(0xFF93C5FD);
      estadoTexto = 'Cambio: ${fmt.format(-restante)}';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.fondoOscuro,
        border: Border(
          top: BorderSide(
              color: AppColors.azulControl.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text('Ingresado: ${fmt.format(ingresado)}',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textoClaroMedio)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: estadoColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: estadoColor.withValues(alpha: 0.4)),
              ),
              child: Text(estadoTexto,
                  style: AppTypography.caption.copyWith(
                      color: estadoColor,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: (puedeCobrar && !cobrando) ? onCobrar : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verdeExito,
              disabledBackgroundColor:
                  AppColors.verdeExito.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 52),
              elevation: 0,
            ),
            child: cobrando
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('COBRAR ${fmt.format(total)}',
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.textoClaroAlto)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Línea label + valor (usada en el diálogo de cambio)
// ---------------------------------------------------------------------------

class _LineaResumen extends StatelessWidget {
  const _LineaResumen({required this.label, required this.valor});
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(label,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textoClaroMedio)),
        const Spacer(),
        Text(valor, style: AppTypography.bodyMedium),
      ]);
}

// ---------------------------------------------------------------------------
// Formatea el monto con puntos de miles mientras se escribe (44000 → 44.000)
// ---------------------------------------------------------------------------

class _MilesInputFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat.decimalPattern('es_CO');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Dejar solo dígitos
    final digitos = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitos.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final numero    = int.parse(digitos);
    final formateado = _fmt.format(numero); // 44000 → "44.000"
    return TextEditingValue(
      text: formateado,
      selection: TextSelection.collapsed(offset: formateado.length),
    );
  }
}
