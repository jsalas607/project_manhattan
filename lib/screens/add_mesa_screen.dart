import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';
import 'mesa_detalle_screen.dart'; // OrdenItem

// ──────────────────────────────────────────────────────────────────────────────
// Resultado que se devuelve al pop
// ──────────────────────────────────────────────────────────────────────────────

class AddMesaResult {
  final Mesa            mesa;
  final List<OrdenItem> orden;
  const AddMesaResult({required this.mesa, required this.orden});
}

// ──────────────────────────────────────────────────────────────────────────────
// Screen
// ──────────────────────────────────────────────────────────────────────────────

class AddMesaScreen extends StatefulWidget {
  const AddMesaScreen({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser    user;

  @override
  State<AddMesaScreen> createState() => _AddMesaScreenState();
}

class _AddMesaScreenState extends State<AddMesaScreen> {
  // ── Form ───────────────────────────────────────────────────────────────────
  final _numeroCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  bool _saving  = false;
  bool _intento = false;

  // ── Categorías + Productos ────────────────────────────────────────────────
  List<Categoria> _categorias   = [];
  List<Producto>  _productos    = [];
  bool            _loadingCats  = true;

  // ── Orden ─────────────────────────────────────────────────────────────────
  final List<OrdenItem> _orden = [];
  static final _fmt = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCats() async {
    final cats  = await MockCategoriasApi.getCategorias(widget.restaurant.id);
    final prods = await MockMenuApi.getProductos(widget.restaurant.id);
    if (!mounted) return;
    setState(() {
      _categorias  = cats;
      _productos   = prods.where((p) => p.visible).toList();
      _loadingCats = false;
    });
  }

  // ── Validación ────────────────────────────────────────────────────────────
  bool _validar() => _numeroCtrl.text.trim().isNotEmpty;

  // ── Orden helpers ─────────────────────────────────────────────────────────
  void _cambiarCantidadPorId(String productoId, int delta) {
    setState(() {
      final idx = _orden.indexWhere((o) => o.producto.id == productoId);
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
  }

  void _cambiarCantidadPorIndex(int index, int delta) {
    setState(() {
      _orden[index].cantidad += delta;
      if (_orden[index].cantidad <= 0) _orden.removeAt(index);
    });
  }

  int _cantidadEnOrden(String productoId) {
    final idx = _orden.indexWhere((o) => o.producto.id == productoId);
    return idx == -1 ? 0 : _orden[idx].cantidad;
  }

  double get _total => _orden.fold(0.0, (s, o) => s + o.subtotal);

  void _mostrarCategoria(Categoria cat) {
    final prods = _productos.where((p) => p.categoriaId == cat.id).toList();
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
          setState(() => _orden.add(
              OrdenItem(producto: p, configuracion: config)));
        },
      ),
    );
  }

  // ── Guardar ───────────────────────────────────────────────────────────────
  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() => _intento = true);
    if (!_validar()) return;
    setState(() => _saving = true);

    final mesa = await MockAtenderMesaApi.addMesa(
      widget.restaurant.id,
      numero: int.tryParse(_numeroCtrl.text.trim()) ?? 0,
      nombre: _nombreCtrl.text.trim(),
    );

    if (!mounted) return;
    Navigator.pop(context, AddMesaResult(mesa: mesa, orden: List.of(_orden)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final errorNumero = _intento && _numeroCtrl.text.trim().isEmpty;

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
        title: Text('Nueva mesa', style: AppTypography.titleLarge),
      ),
      body: Column(
        children: [
          // ── Contenido scrolleable ────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Usuario + sucursal
                  RestaurantHeader(
                      restaurant: widget.restaurant, user: widget.user),
                  const SizedBox(height: 24),

                  // Número de mesa
                  _LabeledField(
                    label: 'Número de mesa',
                    child: TextField(
                      controller: _numeroCtrl,
                      onChanged:  (_) => setState(() {}),
                      style:      AppTypography.bodyMedium,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: _inputDec(
                        hint:  'Ej: 1, 5, 12...',
                        error: errorNumero,
                      ),
                    ),
                  ),
                  if (errorNumero) ...[
                    const SizedBox(height: 4),
                    _errorText('Campo obligatorio'),
                  ],
                  const SizedBox(height: 16),

                  // Nombre del cliente (opcional)
                  _LabeledField(
                    label: 'Nombre del cliente (opcional)',
                    child: TextField(
                      controller: _nombreCtrl,
                      onChanged:  (_) => setState(() {}),
                      style:      AppTypography.bodyMedium,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDec(hint: 'Ej: Carlos Ruiz'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nota informativa
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.azulControl.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              AppColors.azulControl.withValues(alpha: 0.22)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.azulControl, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El número de orden se asigna automáticamente.',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.textoClaroMedio),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 28),

                  // ── Categorías del menú ──────────────────────────────────
                  Row(children: [
                    Text('Agregar al pedido',
                        style: AppTypography.titleMedium),
                    const Spacer(),
                    if (_loadingCats)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.naranjaAccion),
                      ),
                  ]),
                  const SizedBox(height: 12),

                  if (!_loadingCats && _categorias.isEmpty)
                    Text(
                      'Sin categorías disponibles',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textoClaroMedio),
                    )
                  else if (!_loadingCats)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:   2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing:  10,
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

                  // ── Orden actual ──────────────────────────────────────────
                  if (_orden.isNotEmpty) ...[
                    const SizedBox(height: 24),
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
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Barra inferior pegajosa (total + botón) ──────────────────────
          Container(
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
                if (_orden.isNotEmpty) ...[
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
                  const SizedBox(height: 12),
                ],
                ElevatedButton(
                  onPressed: _saving ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.naranjaAccion,
                    disabledBackgroundColor:
                        AppColors.naranjaAccion.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 52),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('ABRIR MESA',
                          style: AppTypography.labelLarge
                              .copyWith(color: AppColors.textoClaroAlto)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Colores de categoría (cíclicos)
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
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: disabled ? 0.06 : 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.category_outlined,
                color: disabled
                    ? AppColors.textoClaroMedio.withValues(alpha: 0.3)
                    : color,
                size: 15,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    cat.nombre,
                    style: AppTypography.labelLarge.copyWith(
                      color: disabled
                          ? AppColors.textoClaroMedio.withValues(alpha: 0.4)
                          : AppColors.textoClaroAlto,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$count producto${count == 1 ? '' : 's'}',
                    style: AppTypography.caption.copyWith(
                      color: disabled
                          ? AppColors.textoClaroMedio.withValues(alpha: 0.3)
                          : AppColors.textoClaroMedio,
                      fontSize: 10,
                    ),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
// Botón de cantidad (+/−)
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
          child: Icon(icon, size: 14, color: AppColors.textoClaroAlto),
        ),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

InputDecoration _inputDec({required String hint, bool error = false}) =>
    InputDecoration(
      hintText:  hint,
      hintStyle: AppTypography.caption.copyWith(
          color: AppColors.textoClaroMedio.withValues(alpha: 0.4)),
      filled:    true,
      fillColor: const Color(0xFF1E293B),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: error
              ? AppColors.rojoAlerta
              : AppColors.azulControl.withValues(alpha: 0.4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: error ? AppColors.rojoAlerta : AppColors.naranjaAccion,
        ),
      ),
    );

Widget _errorText(String msg) => Text(
      msg,
      style: AppTypography.caption.copyWith(color: AppColors.rojoAlerta),
    );

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textoClaroMedio)),
          const SizedBox(height: 6),
          child,
        ],
      );
}

