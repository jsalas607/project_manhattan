import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';
import 'add_producto_screen.dart';
import 'producto_detalle_screen.dart';

class GestionMenuScreen extends StatefulWidget {
  const GestionMenuScreen({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser    user;

  @override
  State<GestionMenuScreen> createState() => _GestionMenuScreenState();
}

class _GestionMenuScreenState extends State<GestionMenuScreen> {
  List<Producto>        _productos  = [];
  List<Categoria>       _categorias = [];
  final Set<String>     _catsFiltro = {};
  bool                  _loading    = true;

  final _fmt = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = await MockMenuApi.getProductos(widget.restaurant.id);
    final c = await MockCategoriasApi.getCategorias(widget.restaurant.id);
    if (!mounted) return;
    setState(() {
      _productos  = p;
      _categorias = c;
      _loading    = false;
    });
  }

  // ── Filtrado ──────────────────────────────────────────────────────────────

  List<Producto> get _filtrados {
    var lista = _productos;
    if (_catsFiltro.isNotEmpty) {
      lista = lista.where((p) => _catsFiltro.contains(p.categoriaId)).toList();
    }
    return lista;
  }

  String _catNombre(String catId) {
    try {
      return _categorias.firstWhere((c) => c.id == catId).nombre;
    } catch (_) {
      return '—';
    }
  }

  // ── Acciones ──────────────────────────────────────────────────────────────

  Future<void> _toggleVisible(Producto p) async {
    final updated =
        await MockMenuApi.toggleVisible(widget.restaurant.id, p.id);
    if (!mounted) return;
    setState(() {
      final idx = _productos.indexWhere((x) => x.id == p.id);
      if (idx != -1) _productos[idx] = updated;
    });
  }

  Future<void> _openDetalle(Producto p) async {
    final eliminado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductoDetalleScreen(
          restaurant:      widget.restaurant,
          user:            widget.user,
          producto:        p,
          categoriaNombre: _catNombre(p.categoriaId),
        ),
      ),
    );
    if (eliminado == true && mounted) {
      setState(() => _productos.removeWhere((x) => x.id == p.id));
    }
  }

  Future<void> _goToAddProducto() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductoScreen(
          restaurant: widget.restaurant,
          user:       widget.user,
          onAdded: (p) => setState(() => _productos = [..._productos, p]),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
        title: Text('Gestionar menú', style: AppTypography.titleLarge),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToAddProducto,
        backgroundColor: AppColors.naranjaAccion,
        elevation: 2,
        icon: const Icon(Icons.add, color: Colors.white, size: 20),
        label: Text(
          'Añadir producto',
          style: AppTypography.caption
              .copyWith(color: AppColors.textoClaroAlto),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.naranjaAccion))
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Usuario + sucursal ────────────────────────────────────
                  RestaurantHeader(
                      restaurant: widget.restaurant, user: widget.user),
                  const SizedBox(height: 20),

                  // ── Filtro por categorías del restaurante ─────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categorias.map((c) {
                        final sel = _catsFiltro.contains(c.id);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _CatChip(
                            label:    c.nombre,
                            selected: sel,
                            onTap: () => setState(() {
                              if (sel) _catsFiltro.remove(c.id);
                              else     _catsFiltro.add(c.id);
                            }),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Tabla de productos ────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.azulControl
                              .withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        // Encabezado
                        const _TableHeader(),
                        const Divider(height: 1, color: Color(0xFF334155)),

                        // Filas
                        if (_filtrados.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              'Sin productos que coincidan.',
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.textoClaroMedio),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ...List.generate(_filtrados.length, (i) {
                            final p = _filtrados[i];
                            return Column(
                              children: [
                                _ProductoRow(
                                  producto:  p,
                                  categoria: _catNombre(p.categoriaId),
                                  fmt:       _fmt,
                                  onToggle:  () => _toggleVisible(p),
                                  onTap:     () => _openDetalle(p),
                                ),
                                if (i < _filtrados.length - 1)
                                  Divider(
                                    height: 1,
                                    color: AppColors.azulControl
                                        .withValues(alpha: 0.15),
                                    indent:    10,
                                    endIndent: 10,
                                  ),
                              ],
                            );
                          }),
                      ],
                    ),
                  ),
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
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 26), // foto
          const SizedBox(width: 8),
          Expanded(
            child: Text('Nombre',
                style: AppTypography.caption.copyWith(
                    color: AppColors.textoClaroMedio,
                    fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 58,
            child: Text('Precio',
                style: AppTypography.caption.copyWith(
                    color: AppColors.textoClaroMedio,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 76,
            child: Text('Categoría',
                style: AppTypography.caption.copyWith(
                    color: AppColors.textoClaroMedio,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 50,
            child: Text('Visible',
                style: AppTypography.caption.copyWith(
                    color: AppColors.textoClaroMedio,
                    fontWeight: FontWeight.w600,
                    fontSize: 10),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fila de producto
// ---------------------------------------------------------------------------

class _ProductoRow extends StatelessWidget {
  const _ProductoRow({
    required this.producto,
    required this.categoria,
    required this.fmt,
    required this.onToggle,
    required this.onTap,
  });

  final Producto         producto;
  final String           categoria;
  final NumberFormat     fmt;
  final VoidCallback     onToggle;
  final VoidCallback     onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            // Foto
            Container(
              width:  26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.azulControl.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.azulControl.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.image_outlined,
                  color: AppColors.textoClaroMedio, size: 14),
            ),
            const SizedBox(width: 8),

            // Nombre
            Expanded(
              child: Text(
                producto.nombre,
                style: AppTypography.bodyMedium,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),

            // Precio
            SizedBox(
              width: 58,
              child: Text(
                fmt.format(producto.precio),
                style: AppTypography.caption.copyWith(
                    color: AppColors.naranjaAccion,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Categoría
            SizedBox(
              width: 76,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.azulControl.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    categoria,
                    style: AppTypography.caption.copyWith(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            // Switch de visibilidad
            SizedBox(
              width: 50,
              child: Center(
                child: Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: producto.visible,
                    onChanged: (_) => onToggle(),
                    activeThumbColor: AppColors.verdeExito,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip de categoría (filtro)
// ---------------------------------------------------------------------------

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.naranjaAccion
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.naranjaAccion
                : AppColors.azulControl.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected
                ? AppColors.textoClaroAlto
                : AppColors.textoClaroMedio,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
