import 'package:flutter/material.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';
import 'add_pantalla_despacho_screen.dart';

class DespacharPedidosScreen extends StatefulWidget {
  const DespacharPedidosScreen({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser    user;

  @override
  State<DespacharPedidosScreen> createState() =>
      _DespacharPedidosScreenState();
}

class _DespacharPedidosScreenState extends State<DespacharPedidosScreen> {
  List<PantallaDespacho> _pantallas  = [];
  List<Categoria>        _categorias = [];
  bool                   _loading    = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pantallas = await MockDespacharApi.getPantallas(widget.restaurant.id);
    final cats      = await MockCategoriasApi.getCategorias(widget.restaurant.id);
    if (!mounted) return;
    setState(() {
      _pantallas  = pantallas;
      _categorias = cats;
      _loading    = false;
    });
  }

  String _nombresCategorias(List<String> ids) {
    final nombres = ids
        .map((id) {
          final cat = _categorias.where((c) => c.id == id);
          return cat.isEmpty ? null : cat.first.nombre;
        })
        .whereType<String>()
        .toList();
    return nombres.isEmpty ? 'Sin categorías' : nombres.join(', ');
  }

  Future<void> _goToAdd() async {
    final nueva = await Navigator.push<PantallaDespacho>(
      context,
      MaterialPageRoute(
        builder: (_) => AddPantallaDespachoScreen(
          restaurant: widget.restaurant,
          user:       widget.user,
        ),
      ),
    );
    if (nueva != null) setState(() => _pantallas = [..._pantallas, nueva]);
  }

  void _onTapPantalla(PantallaDespacho pantalla) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DespachoDetalleScreen(
          pantalla:   pantalla,
          categorias: _categorias,
          restaurant: widget.restaurant,
        ),
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
          icon: const Icon(Icons.arrow_back,
              color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Despachar pedidos', style: AppTypography.titleLarge),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.naranjaAccion))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RestaurantHeader(
                      restaurant: widget.restaurant, user: widget.user),
                  const SizedBox(height: 24),

                  Text('Pantallas de despacho',
                      style: AppTypography.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Cada pantalla muestra solo los productos de las categorías que selecciones.',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textoClaroMedio),
                  ),
                  const SizedBox(height: 16),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:   2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing:  14,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: _pantallas.length + 1,
                    itemBuilder: (_, i) {
                      if (i < _pantallas.length) {
                        final p = _pantallas[i];
                        return _PantallaCard(
                          pantalla:   p,
                          categorias: _nombresCategorias(p.categoriaIds),
                          onTap:      () => _onTapPantalla(p),
                        );
                      }
                      return _AnadirCard(onTap: _goToAdd);
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de pantalla de despacho
// ---------------------------------------------------------------------------

class _PantallaCard extends StatelessWidget {
  const _PantallaCard({
    required this.pantalla,
    required this.categorias,
    required this.onTap,
  });

  final PantallaDespacho pantalla;
  final String           categorias;
  final VoidCallback     onTap;

  @override
  Widget build(BuildContext context) {
    final color = pantalla.color;
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width:  48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(pantalla.icono, color: color, size: 26),
              ),
              const Spacer(),
              Text(
                pantalla.nombre,
                style: AppTypography.titleMedium.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                categorias,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textoClaroMedio),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta añadir
// ---------------------------------------------------------------------------

class _AnadirCard extends StatelessWidget {
  const _AnadirCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.naranjaAccion.withValues(alpha: 0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.naranjaAccion.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width:  52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.naranjaAccion.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add,
                    color: AppColors.naranjaAccion, size: 28),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Añadir pantalla',
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMedium
                      .copyWith(color: AppColors.naranjaAccion),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Pantalla de detalle de despacho — pedidos agrupados por mesa/orden
// ===========================================================================

class _DespachoDetalleScreen extends StatefulWidget {
  const _DespachoDetalleScreen({
    required this.pantalla,
    required this.categorias,
    required this.restaurant,
  });

  final PantallaDespacho pantalla;
  final List<Categoria>  categorias;
  final Restaurant       restaurant;

  @override
  State<_DespachoDetalleScreen> createState() =>
      _DespachoDetalleScreenState();
}

class _DespachoDetalleScreenState extends State<_DespachoDetalleScreen> {
  List<PedidoActivo> _pedidos = [];
  bool               _loading = true;

  // Ítems marcados como listos: clave "pedidoId#indiceItem"
  final Set<String> _listos = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pedidos =
        await MockPedidosApi.getPedidos(widget.restaurant.id);
    // Cargar el estado "listo" persistido de cada mesa
    final listos = <String>{};
    for (final p in pedidos) {
      final idx = await MockPedidosApi.getListos(widget.restaurant.id, p.id);
      for (final i in idx) {
        listos.add('${p.id}#$i');
      }
    }
    if (!mounted) return;
    setState(() {
      _pedidos = pedidos;
      _listos
        ..clear()
        ..addAll(listos);
      _loading = false;
    });
  }

  bool _coincide(ItemPedido item) =>
      widget.pantalla.categoriaIds.contains(item.categoriaId);

  void _toggleListo(String key) {
    final marcar = !_listos.contains(key);
    setState(() {
      if (marcar) {
        _listos.add(key);
      } else {
        _listos.remove(key);
      }
    });
    // Persistir: clave = "mesaId#indice"
    final partes = key.split('#');
    if (partes.length == 2) {
      final mesaId = partes[0];
      final idx    = int.tryParse(partes[1]);
      if (idx != null) {
        MockPedidosApi.setListo(
            widget.restaurant.id, mesaId, idx, listo: marcar);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.pantalla.color;

    // Lista PLANA: aplanar todos los ítems de las categorías de esta pantalla.
    // Cada fila conserva de qué mesa/orden viene.
    final filas = <_FilaDespacho>[];
    for (final p in _pedidos) {
      for (var i = 0; i < p.items.length; i++) {
        if (_coincide(p.items[i])) {
          filas.add(_FilaDespacho(
            key:        '${p.id}#$i',
            mesaNumero: p.mesaNumero,
            orden:      p.orden,
            item:       p.items[i],
          ));
        }
      }
    }

    // Pendientes arriba, listos abajo
    filas.sort((a, b) {
      final la = _listos.contains(a.key) ? 1 : 0;
      final lb = _listos.contains(b.key) ? 1 : 0;
      return la - lb;
    });

    final pendientes =
        filas.where((f) => !_listos.contains(f.key)).length;

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
        title: Row(children: [
          Icon(widget.pantalla.icono, color: color, size: 20),
          const SizedBox(width: 8),
          Text(widget.pantalla.nombre, style: AppTypography.titleLarge),
        ]),
        actions: [
          if (!_loading)
            Container(
              margin:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Text(
                '$pendientes pendiente${pendientes == 1 ? '' : 's'}',
                style: AppTypography.caption.copyWith(
                    color: color, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.naranjaAccion))
          : filas.isEmpty
              ? _EmptyState(color: color)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  itemCount: filas.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final fila  = filas[i];
                    final listo = _listos.contains(fila.key);
                    return _ItemRow(
                      fila:     fila,
                      listo:    listo,
                      color:    color,
                      onToggle: () => _toggleListo(fila.key),
                    );
                  },
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fila aplanada para la lista de despacho
// ---------------------------------------------------------------------------

class _FilaDespacho {
  final String     key;
  final int        mesaNumero;
  final int        orden;
  final ItemPedido item;

  const _FilaDespacho({
    required this.key,
    required this.mesaNumero,
    required this.orden,
    required this.item,
  });
}

// ---------------------------------------------------------------------------
// Fila de un producto a despachar (lista plana, con etiqueta de mesa)
// ---------------------------------------------------------------------------

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.fila,
    required this.listo,
    required this.color,
    required this.onToggle,
  });

  final _FilaDespacho fila;
  final bool          listo;
  final Color         color;
  final VoidCallback  onToggle;

  @override
  Widget build(BuildContext context) {
    final item = fila.item;
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: listo
              ? AppColors.verdeExito.withValues(alpha: 0.06)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: listo
                ? AppColors.verdeExito.withValues(alpha: 0.35)
                : color.withValues(alpha: 0.25),
          ),
        ),
        child: Row(children: [
          // Cantidad
          Container(
            width:  36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: listo
                  ? AppColors.verdeExito.withValues(alpha: 0.15)
                  : color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${item.cantidad}',
                style: AppTypography.titleMedium.copyWith(
                    color: listo ? AppColors.verdeExito : color,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),

          // Nombre + config + mesa
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productoNombre,
                  style: AppTypography.labelLarge.copyWith(
                    decoration:
                        listo ? TextDecoration.lineThrough : null,
                    color: listo
                        ? AppColors.textoClaroMedio
                        : AppColors.textoClaroAlto,
                  ),
                ),
                if (item.config.isNotEmpty)
                  Text(
                    item.config,
                    style: AppTypography.caption.copyWith(
                      color: const Color(0xFF93C5FD),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      decoration:
                          listo ? TextDecoration.lineThrough : null,
                    ),
                  ),
                const SizedBox(height: 3),
                // Etiqueta de mesa / orden
                Row(children: [
                  Icon(Icons.table_restaurant_outlined,
                      size: 11, color: AppColors.textoClaroMedio),
                  const SizedBox(width: 3),
                  Text('Mesa ${fila.mesaNumero} · Orden #${fila.orden}',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.textoClaroMedio,
                          fontSize: 10)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Check listo
          Container(
            width:  26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: listo ? AppColors.verdeExito : Colors.transparent,
              border: Border.all(
                color: listo
                    ? AppColors.verdeExito
                    : AppColors.textoClaroMedio.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: listo
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width:  72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline, color: color, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Sin pedidos pendientes',
                style: AppTypography.titleMedium),
            const SizedBox(height: 4),
            Text('No hay productos de estas categorías por despachar.',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textoClaroMedio)),
          ],
        ),
      );
}

