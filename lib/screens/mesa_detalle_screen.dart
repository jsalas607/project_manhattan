import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';
import 'cobrar_mesa_screen.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Selección de una opción de ingrediente (público — usado en AddMesaScreen)
// ──────────────────────────────────────────────────────────────────────────────

class IngredienteSeleccion {
  final String ingrediente;
  final String opcion;
  const IngredienteSeleccion(
      {required this.ingrediente, required this.opcion});
}

// ──────────────────────────────────────────────────────────────────────────────
// Ítem de la orden (público — compartido con AddMesaScreen)
// ──────────────────────────────────────────────────────────────────────────────

class OrdenItem {
  OrdenItem({
    required this.producto,
    this.cantidad = 1,
    this.configuracion = const [],
  });
  final Producto producto;
  int cantidad;
  final List<IngredienteSeleccion> configuracion;
  double get subtotal => producto.precio * cantidad;

  String get configText => configuracion
      .map((s) => '${s.ingrediente}: ${s.opcion}')
      .join(' · ');
}

// ──────────────────────────────────────────────────────────────────────────────
// Screen principal
// ──────────────────────────────────────────────────────────────────────────────

class MesaDetalleScreen extends StatefulWidget {
  const MesaDetalleScreen({
    super.key,
    required this.mesa,
    required this.restaurant,
    required this.user,
    this.ordenInicial = const [],
  });

  final Mesa            mesa;
  final Restaurant      restaurant;
  final AppUser         user;
  final List<OrdenItem> ordenInicial;

  @override
  State<MesaDetalleScreen> createState() => _MesaDetalleScreenState();
}

class _MesaDetalleScreenState extends State<MesaDetalleScreen> {
  List<Categoria>    _categorias = [];
  List<Producto>     _productos  = [];
  final List<OrdenItem> _orden   = [];
  bool _loading = true;

  static final _fmt = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    for (final o in widget.ordenInicial) {
      _orden.add(
          OrdenItem(producto: o.producto, cantidad: o.cantidad,
              configuracion: o.configuracion));
    }
    if (widget.ordenInicial.isNotEmpty) _persistir();
    _load();
  }

  Future<void> _load() async {
    final cats  = await MockCategoriasApi.getCategorias(widget.restaurant.id);
    final prods = await MockMenuApi.getProductos(widget.restaurant.id);
    final visibles = prods.where((p) => p.visible).toList();

    // Si no vino orden inicial, recuperar el pedido guardado de esta mesa
    if (widget.ordenInicial.isEmpty && _orden.isEmpty) {
      final pedido = await MockPedidosApi.getPedidoMesa(
          widget.restaurant.id, widget.mesa.id);
      if (pedido != null) {
        for (final it in pedido.items) {
          Producto? prod;
          for (final p in prods) {
            if (p.id == it.productoId) { prod = p; break; }
          }
          // Reconstruir configuración a partir del texto guardado
          final config = <IngredienteSeleccion>[];
          if (it.config.isNotEmpty) {
            for (final part in it.config.split(' · ')) {
              final kv = part.split(': ');
              if (kv.length == 2) {
                config.add(IngredienteSeleccion(
                    ingrediente: kv[0], opcion: kv[1]));
              }
            }
          }
          prod ??= Producto(
            id:          it.productoId,
            nombre:      it.productoNombre,
            precio:      0,
            categoriaId: it.categoriaId,
          );
          _orden.add(OrdenItem(
              producto: prod, cantidad: it.cantidad, configuracion: config));
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _categorias = cats;
      _productos  = visibles;
      _loading    = false;
    });
  }

  // ── Orden helpers ──────────────────────────────────────────────────────────

  /// Persiste la orden actual en el almacén central de pedidos (para despacho).
  void _persistir() {
    final items = _orden
        .map((o) => ItemPedido(
              productoId:     o.producto.id,
              productoNombre: o.producto.nombre,
              categoriaId:    o.producto.categoriaId,
              cantidad:       o.cantidad,
              config:         o.configText,
            ))
        .toList();
    MockPedidosApi.guardarPedido(
      widget.restaurant.id,
      mesaId:     widget.mesa.id,
      mesaNumero: widget.mesa.numero,
      orden:      widget.mesa.orden,
      items:      items,
    );
  }

  /// Para productos simples: incrementa qty o crea entrada nueva
  void _cambiarCantidadPorId(String productoId, int delta) {
    setState(() {
      final idx = _orden.indexWhere(
          (o) => o.producto.id == productoId && o.configuracion.isEmpty);
      if (idx == -1) {
        if (delta > 0) {
          final prod = _productos.firstWhere((p) => p.id == productoId);
          _orden.add(OrdenItem(producto: prod));
        }
      } else {
        _orden[idx].cantidad += delta;
        if (_orden[idx].cantidad <= 0) _orden.removeAt(idx);
      }
    });
    _persistir();
  }

  /// Para productos compuestos: siempre agrega nueva entrada con config
  void _agregarCompuesto(Producto p, List<IngredienteSeleccion> config) {
    setState(() => _orden.add(
        OrdenItem(producto: p, configuracion: config)));
    _persistir();
  }

  void _cambiarCantidadPorIndex(int index, int delta) {
    setState(() {
      _orden[index].cantidad += delta;
      if (_orden[index].cantidad <= 0) _orden.removeAt(index);
    });
    _persistir();
  }

  int _cantidadEnOrden(String productoId) => _orden
      .where((o) => o.producto.id == productoId)
      .fold(0, (s, o) => s + o.cantidad);

  double get _total => _orden.fold(0.0, (s, o) => s + o.subtotal);

  // ── Bottom sheet categoría ─────────────────────────────────────────────────

  void _mostrarCategoria(Categoria cat) {
    final prods =
        _productos.where((p) => p.categoriaId == cat.id).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProductosSheet(
        categoria:         cat,
        productos:         prods,
        cantidadFn:        _cantidadEnOrden,
        onCambiarCantidad: _cambiarCantidadPorId,
        onAgregarCompuesto: (p, config) {
          _agregarCompuesto(p, config);
          setState(() {});
        },
      ),
    );
  }

  // ── Cobrar ──────────────────────────────────────────────────────────────────

  Future<void> _irACobrar() async {
    // No se puede cobrar con la caja cerrada
    final caja = await MockCarteraApi.getCajaState(widget.restaurant.id);
    if (!mounted) return;
    if (caja.status == CajaStatus.cerrada) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'La caja está cerrada. Ábrela en Cartera para poder cobrar.'),
          backgroundColor: AppColors.rojoAlerta,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final items = _orden
        .map((o) => ItemPedido(
              productoId:     o.producto.id,
              productoNombre: o.producto.nombre,
              categoriaId:    o.producto.categoriaId,
              cantidad:       o.cantidad,
              config:         o.configText,
            ))
        .toList();

    final cobrada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CobrarMesaScreen(
          mesa:       widget.mesa,
          restaurant: widget.restaurant,
          user:       widget.user,
          items:      items,
          total:      _total,
        ),
      ),
    );
    // Si se cobró, cerrar el detalle devolviendo true para refrescar mesas
    if (cobrada == true && mounted) Navigator.pop(context, true);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
        title: Text('Mesa ${widget.mesa.numero}',
            style: AppTypography.titleLarge),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF60A5FA).withValues(alpha: 0.55)),
            ),
            child: Text(
              'Orden #${widget.mesa.orden}',
              style: AppTypography.caption.copyWith(
                  color: const Color(0xFF93C5FD),
                  fontWeight: FontWeight.w700),
            ),
          ),
          // Icono de cobrar
          IconButton(
            tooltip: 'Cobrar mesa',
            onPressed: _orden.isEmpty ? null : _irACobrar,
            icon: Icon(
              Icons.point_of_sale,
              color: _orden.isEmpty
                  ? AppColors.textoClaroMedio.withValues(alpha: 0.4)
                  : AppColors.verdeExito,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.naranjaAccion))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RestaurantHeader(
                      restaurant: widget.restaurant, user: widget.user),
                  if (widget.mesa.nombre.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.person_outline,
                          size: 14, color: AppColors.textoClaroMedio),
                      const SizedBox(width: 4),
                      Text(widget.mesa.nombre,
                          style: AppTypography.caption.copyWith(
                              color: AppColors.textoClaroMedio)),
                    ]),
                  ],
                  const SizedBox(height: 24),

                  Text('Categorías del menú',
                      style: AppTypography.titleMedium),
                  const SizedBox(height: 12),

                  if (_categorias.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Sin categorías disponibles',
                            style: AppTypography.caption.copyWith(
                                color: AppColors.textoClaroMedio)),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:   2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing:  12,
                        childAspectRatio: 2.4,
                      ),
                      itemCount: _categorias.length,
                      itemBuilder: (_, i) {
                        final cat   = _categorias[i];
                        final color =
                            _kCatColors[i % _kCatColors.length];
                        final count = _productos
                            .where((p) => p.categoriaId == cat.id)
                            .length;
                        return _CatChip(
                          cat:   cat,
                          color: color,
                          count: count,
                          onTap: count == 0
                              ? null
                              : () => _mostrarCategoria(cat),
                        );
                      },
                    ),

                  // ── Orden ───────────────────────────────────────────────
                  if (_orden.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Row(children: [
                      Text('Orden actual',
                          style: AppTypography.titleMedium),
                      const Spacer(),
                      Text(
                        '${_orden.length} ítem${_orden.length == 1 ? '' : 's'}',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.textoClaroMedio),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    ...List.generate(_orden.length, (i) {
                      final item = _orden[i];
                      return _OrdenItemRow(
                        item:    item,
                        onMinus: () => _cambiarCantidadPorIndex(i, -1),
                        onPlus:  () => _cambiarCantidadPorIndex(i,  1),
                        fmt:     _fmt,
                      );
                    }),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Text('Total',
                          style: AppTypography.titleMedium
                              .copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(
                        _fmt.format(_total),
                        style: AppTypography.titleLarge.copyWith(
                            color: AppColors.naranjaAccion,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Colores de categoría (cíclicos, también usados en AddMesaScreen)
// ──────────────────────────────────────────────────────────────────────────────

const _kCatColors = [
  AppColors.naranjaAccion,
  AppColors.azulControl,
  Color(0xFF8B5CF6),
  AppColors.verdeExito,
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
];

// ──────────────────────────────────────────────────────────────────────────────
// Chip de categoría
// ──────────────────────────────────────────────────────────────────────────────

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.cat,
    required this.color,
    required this.count,
    required this.onTap,
  });

  final Categoria     cat;
  final Color         color;
  final int           count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = count == 0;
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withValues(alpha: 0.12),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: disabled
                  ? AppColors.azulControl.withValues(alpha: 0.15)
                  : color.withValues(alpha: 0.4),
            ),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: disabled ? 0.06 : 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.category_outlined,
                  color: disabled
                      ? AppColors.textoClaroMedio.withValues(alpha: 0.3)
                      : color,
                  size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(cat.nombre,
                      style: AppTypography.labelLarge.copyWith(
                        color: disabled
                            ? AppColors.textoClaroMedio
                                .withValues(alpha: 0.4)
                            : AppColors.textoClaroAlto,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('$count producto${count == 1 ? '' : 's'}',
                      style: AppTypography.caption.copyWith(
                        color: disabled
                            ? AppColors.textoClaroMedio
                                .withValues(alpha: 0.3)
                            : AppColors.textoClaroMedio,
                        fontSize: 10,
                      )),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Fila de ítem en la orden
// ──────────────────────────────────────────────────────────────────────────────

class _OrdenItemRow extends StatelessWidget {
  const _OrdenItemRow({
    required this.item,
    required this.onMinus,
    required this.onPlus,
    required this.fmt,
  });

  final OrdenItem    item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.azulControl.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.producto.nombre,
                  style: AppTypography.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (item.configText.isNotEmpty)
                Text(item.configText,
                    style: AppTypography.caption.copyWith(
                        color: const Color(0xFF93C5FD),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis)
              else
                Text(fmt.format(item.producto.precio),
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textoClaroMedio)),
            ],
          ),
        ),
        _QtyBtn(icon: Icons.remove, onTap: onMinus),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('${item.cantidad}',
              style: AppTypography.titleMedium
                  .copyWith(fontWeight: FontWeight.w700)),
        ),
        _QtyBtn(icon: Icons.add, onTap: onPlus),
        const SizedBox(width: 12),
        Text(fmt.format(item.subtotal),
            style: AppTypography.labelLarge.copyWith(
                color: AppColors.naranjaAccion,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Botón de cantidad (+/−) — privado, usado en OrdenItemRow y ProductosSheet
// ──────────────────────────────────────────────────────────────────────────────

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});

  final IconData     icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: AppColors.azulControl.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: AppColors.azulControl.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, size: 14,
              color: AppColors.textoClaroAlto),
        ),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Bottom sheet — lista de productos de una categoría (PÚBLICO)
// ──────────────────────────────────────────────────────────────────────────────

class ProductosSheet extends StatefulWidget {
  const ProductosSheet({
    super.key,
    required this.categoria,
    required this.productos,
    required this.cantidadFn,
    required this.onCambiarCantidad,
    required this.onAgregarCompuesto,
  });

  final Categoria          categoria;
  final List<Producto>     productos;
  final int  Function(String productoId)            cantidadFn;
  final void Function(String productoId, int delta) onCambiarCantidad;
  final void Function(Producto, List<IngredienteSeleccion>) onAgregarCompuesto;

  @override
  State<ProductosSheet> createState() => _ProductosSheetState();
}

class _ProductosSheetState extends State<ProductosSheet> {
  static final _fmt = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  // Cantidades locales para productos simples (reacción visual inmediata)
  late final Map<String, int> _qty;

  @override
  void initState() {
    super.initState();
    _qty = {
      for (final p in widget.productos)
        if (!p.esCompuesto) p.id: widget.cantidadFn(p.id),
    };
  }

  void _tapSimple(Producto p, int delta) {
    final next = ((_qty[p.id] ?? 0) + delta).clamp(0, 99);
    if (next == (_qty[p.id] ?? 0)) return;
    setState(() => _qty[p.id] = next);
    widget.onCambiarCantidad(p.id, delta);
  }

  void _tapCompuesto(BuildContext ctx, Producto p) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CompositeSelectionSheet(
        producto: p,
        onConfirmar: (config) {
          widget.onAgregarCompuesto(p, config);
          // Actualizar badge de cantidad en la sheet
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize:     0.35,
      maxChildSize:     0.9,
      builder: (ctx, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color:
                  AppColors.textoClaroMedio.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text(widget.categoria.nombre,
                  style: AppTypography.titleLarge),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      AppColors.azulControl.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.productos.length} producto'
                  '${widget.productos.length == 1 ? '' : 's'}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.azulControl),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF334155)),
          Expanded(
            child: widget.productos.isEmpty
                ? Center(
                    child: Text('Sin productos en esta categoría',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.textoClaroMedio)),
                  )
                : ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: widget.productos.length,
                    separatorBuilder: (_, i) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final p = widget.productos[i];
                      if (p.esCompuesto) {
                        return _CompuestoProdRow(
                          producto:    p,
                          enOrden:     widget.cantidadFn(p.id),
                          fmt:         _fmt,
                          onAnadir:    () => _tapCompuesto(ctx, p),
                        );
                      }
                      final qty = _qty[p.id] ?? 0;
                      return _SimpleProdRow(
                        producto: p,
                        qty:      qty,
                        fmt:      _fmt,
                        onMinus:  () => _tapSimple(p, -1),
                        onPlus:   () => _tapSimple(p,  1),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

// ── Fila de producto simple ───────────────────────────────────────────────────

class _SimpleProdRow extends StatelessWidget {
  const _SimpleProdRow({
    required this.producto,
    required this.qty,
    required this.fmt,
    required this.onMinus,
    required this.onPlus,
  });

  final Producto     producto;
  final int          qty;
  final NumberFormat fmt;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.fondoOscuro,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: qty > 0
              ? AppColors.naranjaAccion.withValues(alpha: 0.45)
              : AppColors.azulControl.withValues(alpha: 0.2),
        ),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.naranjaAccion.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.fastfood_outlined,
              color: AppColors.naranjaAccion, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(producto.nombre,
                  style: AppTypography.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(fmt.format(producto.precio),
                  style: AppTypography.caption.copyWith(
                      color: AppColors.naranjaAccion,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (qty == 0)
          GestureDetector(
            onTap: onPlus,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.naranjaAccion.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.naranjaAccion
                        .withValues(alpha: 0.5)),
              ),
              child: Text('Añadir',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.naranjaAccion,
                      fontWeight: FontWeight.w600)),
            ),
          )
        else
          Row(children: [
            _QtyBtn(icon: Icons.remove, onTap: onMinus),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10),
              child: Text('$qty',
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
            _QtyBtn(icon: Icons.add, onTap: onPlus),
          ]),
      ]),
    );
  }
}

// ── Fila de producto compuesto ────────────────────────────────────────────────

class _CompuestoProdRow extends StatelessWidget {
  const _CompuestoProdRow({
    required this.producto,
    required this.enOrden,
    required this.fmt,
    required this.onAnadir,
  });

  final Producto     producto;
  final int          enOrden;
  final NumberFormat fmt;
  final VoidCallback onAnadir;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.fondoOscuro,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enOrden > 0
              ? AppColors.naranjaAccion.withValues(alpha: 0.45)
              : AppColors.azulControl.withValues(alpha: 0.2),
        ),
      ),
      child: Row(children: [
        // Ícono con badge de variantes
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tune,
                  color: Color(0xFF8B5CF6), size: 18),
            ),
            Positioned(
              top: -4, right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('VAR',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(producto.nombre,
                  style: AppTypography.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(fmt.format(producto.precio),
                  style: AppTypography.caption.copyWith(
                      color: AppColors.naranjaAccion,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (enOrden > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.naranjaAccion
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('En orden: $enOrden',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.naranjaAccion,
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
              ),
            GestureDetector(
              onTap: onAnadir,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF8B5CF6)
                          .withValues(alpha: 0.5)),
                ),
                child: Text('Elegir',
                    style: AppTypography.caption.copyWith(
                        color: const Color(0xFF8B5CF6),
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Pantalla de selección de opciones (PÚBLICO — usado también en AddMesaScreen)
// ──────────────────────────────────────────────────────────────────────────────

class CompositeSelectionSheet extends StatefulWidget {
  const CompositeSelectionSheet({
    super.key,
    required this.producto,
    required this.onConfirmar,
  });

  final Producto                                      producto;
  final void Function(List<IngredienteSeleccion>)     onConfirmar;

  @override
  State<CompositeSelectionSheet> createState() =>
      _CompositeSelectionSheetState();
}

class _CompositeSelectionSheetState
    extends State<CompositeSelectionSheet> {
  static final _fmt = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  late final Map<String, String?> _selecciones;

  @override
  void initState() {
    super.initState();
    _selecciones = {};
    for (final ing in widget.producto.ingredientes) {
      if (ing.obligatorio && ing.opciones.isNotEmpty) {
        _selecciones[ing.nombre] = ing.opciones.first.nombre;
      } else {
        _selecciones[ing.nombre] = null; // requiere selección
      }
    }
  }

  bool get _listo =>
      _selecciones.values.every((v) => v != null);

  void _confirmar() {
    final config = widget.producto.ingredientes
        .map((ing) => IngredienteSeleccion(
              ingrediente: ing.nombre,
              opcion:      _selecciones[ing.nombre]!,
            ))
        .toList();
    widget.onConfirmar(config);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize:     0.45,
      maxChildSize:     0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color:
                  AppColors.textoClaroMedio.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Encabezado: nombre + precio
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.producto.nombre,
                        style: AppTypography.titleLarge),
                    Text('Elige tus opciones',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.textoClaroMedio)),
                  ],
                ),
              ),
              Text(_fmt.format(widget.producto.precio),
                  style: AppTypography.titleMedium.copyWith(
                      color: AppColors.naranjaAccion,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF334155)),

          // Lista de ingredientes
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: widget.producto.ingredientes.length,
              itemBuilder: (_, i) {
                final ing = widget.producto.ingredientes[i];
                return _IngredienteSection(
                  ingrediente:    ing,
                  seleccionado:   _selecciones[ing.nombre],
                  onSeleccionar:  (opcion) =>
                      setState(() => _selecciones[ing.nombre] = opcion),
                );
              },
            ),
          ),

          // Botón confirmar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: ElevatedButton(
              onPressed: _listo ? _confirmar : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.naranjaAccion,
                disabledBackgroundColor:
                    AppColors.naranjaAccion.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 50),
                elevation: 0,
              ),
              child: Text(
                _listo ? 'AÑADIR A LA ORDEN' : 'Selecciona todas las opciones',
                style: AppTypography.labelLarge.copyWith(
                    color: _listo
                        ? AppColors.textoClaroAlto
                        : AppColors.textoClaroMedio),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Sección de un ingrediente en el selection sheet ──────────────────────────

class _IngredienteSection extends StatelessWidget {
  const _IngredienteSection({
    required this.ingrediente,
    required this.seleccionado,
    required this.onSeleccionar,
  });

  final IngredienteReceta  ingrediente;
  final String?            seleccionado;
  final void Function(String) onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título del ingrediente
          Row(children: [
            Text(ingrediente.nombre,
                style: AppTypography.titleMedium),
            const SizedBox(width: 6),
            if (ingrediente.obligatorio)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.verdeExito.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: AppColors.verdeExito
                          .withValues(alpha: 0.3)),
                ),
                child: Text('Incluido',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.verdeExito,
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.naranjaAccion.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Requerido',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.naranjaAccion,
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 10),

          if (ingrediente.obligatorio)
            // Auto-seleccionado — solo muestra el valor
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.verdeExito.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.verdeExito.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle,
                    color: AppColors.verdeExito, size: 18),
                const SizedBox(width: 10),
                Text(ingrediente.opciones.first.nombre,
                    style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.verdeExito)),
                const Spacer(),
                Text('Auto-incluido',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.verdeExito.withValues(
                            alpha: 0.7),
                        fontSize: 10)),
              ]),
            )
          else
            // Opciones seleccionables
            Column(
              children: ingrediente.opciones.map((op) {
                final selected = seleccionado == op.nombre;
                return GestureDetector(
                  onTap: () => onSeleccionar(op.nombre),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.naranjaAccion
                              .withValues(alpha: 0.08)
                          : AppColors.fondoOscuro,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.naranjaAccion
                                .withValues(alpha: 0.6)
                            : AppColors.azulControl
                                .withValues(alpha: 0.2),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      // Radio circle
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? AppColors.naranjaAccion
                                : AppColors.azulControl
                                    .withValues(alpha: 0.4),
                            width: 2,
                          ),
                          color: selected
                              ? AppColors.naranjaAccion
                              : Colors.transparent,
                        ),
                        child: selected
                            ? const Icon(Icons.check,
                                size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(op.nombre,
                          style: AppTypography.bodyMedium.copyWith(
                            color: selected
                                ? AppColors.textoClaroAlto
                                : AppColors.textoClaroMedio,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          )),
                    ]),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

