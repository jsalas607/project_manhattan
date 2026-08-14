import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_exception.dart';
import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import 'add_categoria_screen.dart';

// Colores que se asignan a las categorías de forma cíclica
const _kCatColors = [
  AppColors.naranjaAccion,
  AppColors.azulControl,
  Color(0xFF8B5CF6),
  AppColors.verdeExito,
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
];

// ---------------------------------------------------------------------------
// Pantalla principal — grid de categorías
// ---------------------------------------------------------------------------

class VerMenuScreen extends StatefulWidget {
  const VerMenuScreen({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser    user;

  @override
  State<VerMenuScreen> createState() => _VerMenuScreenState();
}

class _VerMenuScreenState extends State<VerMenuScreen> {
  List<Categoria> _categorias = [];
  List<Producto>  _productos  = [];
  bool            _loading    = true;

  final _fmt = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats  = await MockCategoriasApi.getCategorias(widget.restaurant.id);
    final prods = await MockMenuApi.getProductos(widget.restaurant.id);
    if (!mounted) return;
    setState(() {
      _categorias = cats;
      _productos  = prods.where((p) => p.visible).toList();
      _loading    = false;
    });
  }

  List<Producto> _prodsDeCat(String catId) =>
      _productos.where((p) => p.categoriaId == catId).toList();

  Future<void> _addCategoria() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCategoriaScreen(
          restaurant: widget.restaurant,
          user:       widget.user,
          onAdded:    (_) {},
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _deleteCategoria(Categoria c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Eliminar categoría', style: AppTypography.titleMedium),
        content: Text(
          '¿Eliminar la categoría «${c.nombre}»?',
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
    try {
      await MockCategoriasApi.deleteCategoria(widget.restaurant.id, c.id);
      if (!mounted) return;
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.rojoAlerta,
          content: Text(
            e.statusCode == 409
                ? 'No se puede eliminar «${c.nombre}»: tiene productos. '
                    'Elimínalos primero.'
                : 'No se pudo eliminar: ${e.message}',
          ),
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
        title: Text('Menú', style: AppTypography.titleLarge),
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
                  // Restaurante (texto plano, sin caja)
                  Text(widget.restaurant.title,
                      style: AppTypography.titleLarge),
                  const SizedBox(height: 20),

                  Text('Categorías',
                      style: AppTypography.titleMedium),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:   2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing:  14,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _categorias.length + 1,
                    itemBuilder: (_, i) {
                      // Última posición = tarjeta "Añadir"
                      if (i == _categorias.length) {
                        return _AddCatCard(onTap: _addCategoria);
                      }
                      final cat   = _categorias[i];
                      final prods = _prodsDeCat(cat.id);
                      final color = _kCatColors[i % _kCatColors.length];
                      return _CatCard(
                        categoria: cat,
                        count:     prods.length,
                        color:     color,
                        onDelete:  () => _deleteCategoria(cat),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _VerMenuCategoriaScreen(
                                restaurant: widget.restaurant,
                                categoria:  cat,
                                productos:  prods,
                                color:      color,
                                fmt:        _fmt,
                              ),
                            ),
                          );
                          if (mounted) _load();
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de categoría
// ---------------------------------------------------------------------------

class _CatCard extends StatelessWidget {
  const _CatCard({
    required this.categoria,
    required this.count,
    required this.color,
    required this.onTap,
    this.onDelete,
  });

  final Categoria     categoria;
  final int           count;
  final Color         color;
  final VoidCallback  onTap;
  final VoidCallback? onDelete;

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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Stack(
            children: [
              Column(
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
                    child: Icon(Icons.category_outlined,
                        color: color, size: 28),
                  ),
                  const SizedBox(height: 12),

                  // Nombre
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      categoria.nombre,
                      style: AppTypography.titleMedium,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Conteo de productos
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color:        color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      count == 0
                          ? 'Sin productos'
                          : count == 1
                              ? '1 producto'
                              : '$count productos',
                      style: AppTypography.caption.copyWith(
                          color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              // Botón eliminar (esquina superior derecha)
              if (onDelete != null)
                Positioned(
                  top:   6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onDelete,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.rojoAlerta.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.close,
                          size: 14, color: AppColors.rojoAlerta),
                    ),
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
// Tarjeta "Añadir categoría"
// ---------------------------------------------------------------------------

class _AddCatCard extends StatelessWidget {
  const _AddCatCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.naranjaAccion.withValues(alpha: 0.1),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.naranjaAccion.withValues(alpha: 0.35)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width:  44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.naranjaAccion.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.add,
                      color: AppColors.naranjaAccion, size: 24),
                ),
                const SizedBox(height: 8),
                Text('Añadir',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.naranjaAccion)),
              ],
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Pantalla de productos de una categoría
// ---------------------------------------------------------------------------

class _VerMenuCategoriaScreen extends StatefulWidget {
  const _VerMenuCategoriaScreen({
    required this.restaurant,
    required this.categoria,
    required this.productos,
    required this.color,
    required this.fmt,
  });

  final Restaurant    restaurant;
  final Categoria     categoria;
  final List<Producto> productos;
  final Color         color;
  final NumberFormat  fmt;

  @override
  State<_VerMenuCategoriaScreen> createState() =>
      _VerMenuCategoriaScreenState();
}

class _VerMenuCategoriaScreenState extends State<_VerMenuCategoriaScreen> {
  late final List<Producto> _productos = List.of(widget.productos);
  bool _deleting = false;

  Future<void> _confirmDelete(Producto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Eliminar del menú', style: AppTypography.titleMedium),
        content: Text(
          'Se eliminará «${p.nombre}» del menú.\n\n'
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
      await MockMenuApi.deleteProducto(widget.restaurant.id, p.id);
      if (!mounted) return;
      setState(() {
        _productos.removeWhere((x) => x.id == p.id);
        _deleting = false;
      });
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
          icon: const Icon(Icons.arrow_back,
              color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.categoria.nombre,
            style: AppTypography.titleLarge),
      ),
      body: _productos.isEmpty
          ? _EmptyState(mensaje: 'Esta categoría no tiene productos.')
          : ListView.separated(
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: _productos.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: 10),
              itemBuilder: (_, i) => _ProductoCard(
                producto: _productos[i],
                color:    widget.color,
                fmt:      widget.fmt,
                onDelete:
                    _deleting ? null : () => _confirmDelete(_productos[i]),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de producto
// ---------------------------------------------------------------------------

class _ProductoCard extends StatelessWidget {
  const _ProductoCard({
    required this.producto,
    required this.color,
    required this.fmt,
    this.onDelete,
  });

  final Producto      producto;
  final Color         color;
  final NumberFormat  fmt;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Foto placeholder
          Container(
            width:  56,
            height: 56,
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(Icons.fastfood_outlined,
                color: color, size: 26),
          ),
          const SizedBox(width: 14),

          // Nombre
          Expanded(
            child: Text(
              producto.nombre,
              style: AppTypography.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Precio
          Text(
            fmt.format(producto.precio),
            style: AppTypography.titleMedium.copyWith(
                color: AppColors.naranjaAccion),
          ),

          // Eliminar
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            IconButton(
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 34, minHeight: 34),
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.rojoAlerta, size: 20),
              tooltip: 'Eliminar del menú',
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Estado vacío
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {this.mensaje = 'No hay categorías creadas todavía.'});
  final String mensaje;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined,
                color:
                    AppColors.textoClaroMedio.withValues(alpha: 0.3),
                size: 64),
            const SizedBox(height: 16),
            Text(
              mensaje,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textoClaroMedio),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
