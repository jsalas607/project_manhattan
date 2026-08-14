import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';

class AddGastoScreen extends StatefulWidget {
  const AddGastoScreen({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser user;

  @override
  State<AddGastoScreen> createState() => _AddGastoScreenState();
}

// ---------------------------------------------------------------------------
// Modelo interno de fila de producto
// ---------------------------------------------------------------------------

class _ProductoRow {
  String name = '';
  InventoryItem? selectedItem; // null = escrito manualmente
  final unidadCtrl   = TextEditingController();
  final cantidadCtrl = TextEditingController();

  bool get fromCatalog => selectedItem != null;

  void dispose() {
    unidadCtrl.dispose();
    cantidadCtrl.dispose();
  }
}

// ---------------------------------------------------------------------------
// State principal
// ---------------------------------------------------------------------------

// Tipos de gasto
enum _TipoGasto { productos, servicio }

// Categorías de servicio predefinidas
const _kServicios = <_ServicioCat>[
  _ServicioCat('Luz',      Icons.lightbulb_outline),
  _ServicioCat('Agua',     Icons.water_drop_outlined),
  _ServicioCat('Gas',      Icons.local_fire_department_outlined),
  _ServicioCat('Arriendo', Icons.home_outlined),
  _ServicioCat('Internet', Icons.wifi),
  _ServicioCat('Otro',     Icons.receipt_long_outlined),
];

class _ServicioCat {
  final String   nombre;
  final IconData icono;
  const _ServicioCat(this.nombre, this.icono);
}

class _AddGastoScreenState extends State<AddGastoScreen> {
  final _tituloCtrl     = TextEditingController();
  final _precioCtrl     = TextEditingController();
  final _otroCatCtrl    = TextEditingController(); // nombre de categoría "Otro"
  String? _metodoPago;
  final List<_ProductoRow> _filas = [];
  bool _saving = false;

  _TipoGasto _tipo        = _TipoGasto.productos;
  String?    _servicioSel; // categoría de servicio elegida
  List<String> _customCats = []; // categorías nuevas creadas por el admin
  List<InventoryItem> _catalog = [];

  bool get _esOtro => _servicioSel == 'Otro';

  List<String> get _methods => widget.restaurant.paymentMethods.isNotEmpty
      ? widget.restaurant.paymentMethods
      : ['efectivo'];

  @override
  void initState() {
    super.initState();
    _metodoPago = _methods.first;
    _filas.add(_ProductoRow()); // siempre arranca con una fila
    _loadCustomCats();
    _loadCatalog();
  }

  Future<void> _loadCustomCats() async {
    final cats = await MockServiciosApi.getCategorias(widget.restaurant.id);
    if (!mounted) return;
    setState(() => _customCats = cats);
  }

  Future<void> _loadCatalog() async {
    final catalog = await MockInventoryApi.getCatalog(widget.restaurant.id);
    if (!mounted) return;
    setState(() => _catalog = catalog);
  }

  /// Diálogo para crear una categoría de servicio nueva.
  Future<void> _crearCategoria() async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Nueva categoría', style: AppTypography.titleMedium),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: AppTypography.bodyLarge,
          cursorColor: AppColors.naranjaAccion,
          decoration: InputDecoration(
            hintText: 'Ej: Aseo, Mantenimiento…',
            hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.textoClaroMedio.withValues(alpha: 0.4)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: AppColors.naranjaAccion, width: 1.5),
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.textoClaroMedio)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.naranjaAccion,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 12),
              elevation: 0,
            ),
            child: Text('Crear',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.textoClaroAlto)),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (nombre == null || nombre.isEmpty) return;
    await MockServiciosApi.addCategoria(widget.restaurant.id, nombre);
    if (!mounted) return;
    await _loadCustomCats();
    // Seleccionar automáticamente la categoría recién creada
    setState(() => _servicioSel = nombre);
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _precioCtrl.dispose();
    _otroCatCtrl.dispose();
    for (final f in _filas) {
      f.dispose();
    }
    super.dispose();
  }

  void _addFila() => setState(() => _filas.add(_ProductoRow()));

  void _removeFila(int i) {
    setState(() {
      _filas[i].dispose();
      _filas.removeAt(i);
    });
  }

  Future<void> _save() async {
    final esServicio = _tipo == _TipoGasto.servicio;
    // Categoría efectiva: si es "Otro", el nombre escrito por el usuario
    final categoria = _esOtro ? _otroCatCtrl.text.trim() : _servicioSel;
    // En servicio, si no escribió título, usa la categoría como título
    var titulo = _tituloCtrl.text.trim();
    if (esServicio && titulo.isEmpty && categoria != null && categoria.isNotEmpty) {
      titulo = categoria;
    }
    final monto = double.tryParse(
            _precioCtrl.text.replaceAll('.', '').replaceAll(',', '')) ??
        0;

    // Validar precio (siempre obligatorio)
    if (monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el precio del gasto')),
      );
      return;
    }

    if (esServicio) {
      // Validar categoría de servicio
      if (_servicioSel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elige el tipo de servicio')),
        );
        return;
      }
      // Si es "Otro", exigir el nombre de la categoría
      if (_esOtro && _otroCatCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escribe el nombre del servicio')),
        );
        return;
      }
      setState(() => _saving = true);
      // Gasto de servicio: sin productos, no toca inventario
      await MockCarteraApi.addGasto(
        widget.restaurant.id,
        titulo,
        monto,
        metodoPago: _metodoPago ?? _methods.first,
        productos: const [],
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      return;
    }

    // ── Gasto con productos ────────────────────────────────────────────────
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa el título del gasto')),
      );
      return;
    }

    final filasValidas = _filas
        .where((f) =>
            f.name.isNotEmpty &&
            (double.tryParse(f.cantidadCtrl.text) ?? 0) > 0)
        .toList();

    if (filasValidas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Agrega al menos un producto con cantidad')),
      );
      return;
    }

    setState(() => _saving = true);

    final productos = filasValidas
        .map((f) => GastoProducto(
              name:     f.name,
              unidad:   f.unidadCtrl.text.trim(),
              cantidad: double.tryParse(f.cantidadCtrl.text) ?? 0,
            ))
        .toList();

    // 1. Registrar el gasto
    await MockCarteraApi.addGasto(
      widget.restaurant.id,
      titulo,
      monto,
      metodoPago: _metodoPago ?? _methods.first,
      productos: productos,
    );

    // 2. Actualizar el inventario
    final today = DateTime.now();
    for (final f in filasValidas) {
      final cantidad = double.tryParse(f.cantidadCtrl.text) ?? 0;
      if (cantidad <= 0) continue;

      if (f.selectedItem != null) {
        await MockInventoryApi.addCompra(
            widget.restaurant.id, today, f.selectedItem!.id, cantidad);
      } else {
        final unidad = f.unidadCtrl.text.trim();
        if (unidad.isNotEmpty) {
          final newItem = await MockInventoryApi.addItemToday(
            widget.restaurant.id,
            name:   f.name,
            unidad: unidad,
          );
          await MockInventoryApi.addCompra(
              widget.restaurant.id, today, newItem.id, cantidad);
        }
      }
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

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
        title: Text('Añadir gasto', style: AppTypography.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Usuario + sucursal
            RestaurantHeader(restaurant: widget.restaurant, user: widget.user),
            const SizedBox(height: 20),

            // Selector de tipo de gasto
            Text('Tipo de gasto', style: AppTypography.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TipoBtn(
                    label:    'Productos',
                    icono:    Icons.inventory_2_outlined,
                    seleccionado: _tipo == _TipoGasto.productos,
                    onTap: () =>
                        setState(() => _tipo = _TipoGasto.productos),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TipoBtn(
                    label:    'Servicio',
                    icono:    Icons.receipt_long_outlined,
                    seleccionado: _tipo == _TipoGasto.servicio,
                    onTap: () =>
                        setState(() => _tipo = _TipoGasto.servicio),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Categoría de servicio (solo modo servicio) ──────────────
            if (_tipo == _TipoGasto.servicio) ...[
              Text('Tipo de servicio', style: AppTypography.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Categorías predefinidas
                  for (final s in _kServicios)
                    _ChipCategoria(
                      nombre: s.nombre,
                      icono:  s.icono,
                      seleccionado: _servicioSel == s.nombre,
                      onTap: () =>
                          setState(() => _servicioSel = s.nombre),
                    ),
                  // Categorías creadas por el admin
                  for (final c in _customCats)
                    _ChipCategoria(
                      nombre: c,
                      icono:  Icons.label_outline,
                      seleccionado: _servicioSel == c,
                      onTap: () => setState(() => _servicioSel = c),
                    ),
                  // Botón añadir categoría nueva
                  GestureDetector(
                    onTap: _crearCategoria,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.verdeExito.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.verdeExito
                                .withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add,
                              size: 16, color: AppColors.verdeExito),
                          const SizedBox(width: 6),
                          Text('Añadir',
                              style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.verdeExito,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Campo para nombrar la categoría — solo cuando es "Otro"
              if (_esOtro) ...[
                const SizedBox(height: 12),
                Text('Nombre del servicio', style: AppTypography.labelLarge),
                const SizedBox(height: 6),
                _DarkField(
                  ctrl: _otroCatCtrl,
                  hint: 'Ej: Aseo, Mantenimiento, Publicidad…',
                ),
              ],
              const SizedBox(height: 20),
            ],

            // Título del gasto (opcional en servicio)
            Text(
              _tipo == _TipoGasto.servicio
                  ? 'Detalle (opcional)'
                  : 'Título del gasto',
              style: AppTypography.labelLarge,
            ),
            const SizedBox(height: 6),
            _DarkField(
              ctrl: _tituloCtrl,
              hint: _tipo == _TipoGasto.servicio
                  ? 'Ej: Recibo de luz junio…'
                  : 'Ej: Gas cocina, Servilletas…',
            ),
            const SizedBox(height: 16),

            // Precio + método de pago
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Precio del gasto', style: AppTypography.labelLarge),
                      const SizedBox(height: 6),
                      _DarkField(ctrl: _precioCtrl, hint: '0', numeric: true),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Método de pago', style: AppTypography.labelLarge),
                      const SizedBox(height: 6),
                      _MethodDropdown(
                        value: _metodoPago,
                        methods: _methods,
                        onChanged: (v) => setState(() => _metodoPago = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Sección de productos (solo modo productos) ──────────────
            if (_tipo == _TipoGasto.productos) ...[
              // Divisor productos
              Row(
                children: [
                  Expanded(
                      child: Divider(
                          color:
                              AppColors.azulControl.withValues(alpha: 0.3))),
                  const SizedBox(width: 10),
                  Row(
                    children: [
                      Text('Productos', style: AppTypography.caption),
                      const SizedBox(width: 4),
                      Text('*',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.rojoAlerta)),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Divider(
                          color:
                              AppColors.azulControl.withValues(alpha: 0.3))),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Mínimo un producto — se actualizará el inventario',
                style: AppTypography.caption.copyWith(
                    color: AppColors.naranjaAccion.withValues(alpha: 0.8)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Filas de producto
              ..._filas.asMap().entries.map(
                    (e) => _ProductoRowWidget(
                      key: ValueKey(e.key),
                      row: e.value,
                      catalog: _catalog,
                      onRemove: () => _removeFila(e.key),
                      onChanged: () => setState(() {}),
                    ),
                  ),

              // Botón añadir producto
              OutlinedButton.icon(
                onPressed: _addFila,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textoClaroMedio,
                  side: BorderSide(
                      color: AppColors.azulControl.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Añadir otro producto'),
              ),
            ],
            const SizedBox(height: 32),

            // Botón registrar
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.textoClaroAlto),
                    )
                  : const Text('Registrar gasto'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget de fila de producto
// ---------------------------------------------------------------------------

class _ProductoRowWidget extends StatefulWidget {
  const _ProductoRowWidget({
    super.key,
    required this.row,
    required this.catalog,
    required this.onRemove,
    required this.onChanged,
  });

  final _ProductoRow row;
  final List<InventoryItem> catalog;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  State<_ProductoRowWidget> createState() => _ProductoRowWidgetState();
}

class _ProductoRowWidgetState extends State<_ProductoRowWidget> {
  // Guardamos referencia al controller del Autocomplete para manejar el listener
  TextEditingController? _trackedCtrl;

  void _onNameChanged() {
    if (_trackedCtrl == null) return;
    final text = _trackedCtrl!.text;
    // Si el usuario borra o cambia el texto después de seleccionar del catálogo
    if (widget.row.selectedItem != null &&
        text != widget.row.selectedItem!.name) {
      setState(() {
        widget.row.selectedItem = null;
        widget.row.unidadCtrl.clear();
      });
      widget.onChanged();
    }
    // Rebuild para mostrar/ocultar el badge "nuevo"
    setState(() => widget.row.name = text);
    widget.onChanged();
  }

  @override
  void dispose() {
    _trackedCtrl?.removeListener(_onNameChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.azulControl.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado fila
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Producto', style: AppTypography.labelLarge),
                  // Badge "nuevo" cuando el nombre está escrito manualmente
                  if (widget.row.name.isNotEmpty && !widget.row.fromCatalog) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.verdeExito.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.verdeExito.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '+ nuevo en inventario',
                        style: AppTypography.caption.copyWith(color: AppColors.verdeExito),
                      ),
                    ),
                  ],
                ],
              ),
              GestureDetector(
                onTap: widget.onRemove,
                child: const Icon(Icons.close,
                    size: 18, color: AppColors.rojoAlerta),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Autocomplete
          Autocomplete<InventoryItem>(
            optionsBuilder: (TextEditingValue val) {
              if (val.text.trim().isEmpty) return const Iterable.empty();
              return widget.catalog.where((item) =>
                  item.name.toLowerCase().contains(val.text.toLowerCase()));
            },
            displayStringForOption: (item) => item.name,
            onSelected: (item) {
              setState(() {
                widget.row.selectedItem = item;
                widget.row.name = item.name;
                widget.row.unidadCtrl.text = item.unidad;
              });
              widget.onChanged();
            },
            fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmitted) {
              // Registrar listener una sola vez
              if (_trackedCtrl != textCtrl) {
                _trackedCtrl?.removeListener(_onNameChanged);
                _trackedCtrl = textCtrl;
                textCtrl.addListener(_onNameChanged);
              }
              return _buildRawField(
                controller: textCtrl,
                focusNode: focusNode,
                hint: 'Buscar ingrediente o escribir nombre…',
              );
            },
            optionsViewBuilder: (ctx, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: const Color(0xFF0F172A),
                elevation: 6,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (_, i) {
                      final item = options.elementAt(i);
                      return ListTile(
                        dense: true,
                        title: Text(item.name, style: AppTypography.bodyMedium),
                        trailing:
                            Text(item.unidad, style: AppTypography.caption),
                        onTap: () => onSelected(item),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Unidad + Cantidad
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unidad de medida', style: AppTypography.caption),
                    const SizedBox(height: 4),
                    _buildRawField(
                      controller: widget.row.unidadCtrl,
                      hint: 'kg, gr, und…',
                      enabled: !widget.row.fromCatalog,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cantidad', style: AppTypography.caption),
                    const SizedBox(height: 4),
                    _buildRawField(
                      controller: widget.row.cantidadCtrl,
                      hint: '0',
                      numeric: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers / widgets internos
// ---------------------------------------------------------------------------

class _ChipCategoria extends StatelessWidget {
  const _ChipCategoria({
    required this.nombre,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });

  final String       nombre;
  final IconData     icono;
  final bool         seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColors.naranjaAccion.withValues(alpha: 0.15)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: seleccionado
                ? AppColors.naranjaAccion
                : AppColors.azulControl.withValues(alpha: 0.3),
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono,
                size: 16,
                color: seleccionado
                    ? AppColors.naranjaAccion
                    : AppColors.textoClaroMedio),
            const SizedBox(width: 6),
            Text(nombre,
                style: AppTypography.bodyMedium.copyWith(
                  color: seleccionado
                      ? AppColors.naranjaAccion
                      : AppColors.textoClaroMedio,
                  fontWeight:
                      seleccionado ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}

class _TipoBtn extends StatelessWidget {
  const _TipoBtn({
    required this.label,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });

  final String       label;
  final IconData     icono;
  final bool         seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColors.naranjaAccion.withValues(alpha: 0.15)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado
                ? AppColors.naranjaAccion
                : AppColors.azulControl.withValues(alpha: 0.3),
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icono,
                size: 22,
                color: seleccionado
                    ? AppColors.naranjaAccion
                    : AppColors.textoClaroMedio),
            const SizedBox(height: 6),
            Text(label,
                style: AppTypography.bodyMedium.copyWith(
                  color: seleccionado
                      ? AppColors.naranjaAccion
                      : AppColors.textoClaroMedio,
                  fontWeight:
                      seleccionado ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}


class _DarkField extends StatelessWidget {
  const _DarkField(
      {required this.ctrl, required this.hint, this.numeric = false});
  final TextEditingController ctrl;
  final String hint;
  final bool numeric;

  @override
  Widget build(BuildContext context) =>
      _buildRawField(controller: ctrl, hint: hint, numeric: numeric);
}

Widget _buildRawField({
  required TextEditingController controller,
  FocusNode? focusNode,
  required String hint,
  bool numeric = false,
  bool enabled = true,
}) {
  return TextField(
    controller: controller,
    focusNode: focusNode,
    enabled: enabled,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    inputFormatters: numeric
        ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
        : null,
    style: AppTypography.bodyLarge,
    cursorColor: AppColors.naranjaAccion,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyMedium
          .copyWith(color: AppColors.textoClaroMedio.withValues(alpha: 0.4)),
      filled: true,
      fillColor: enabled
          ? const Color(0xFF0F172A)
          : const Color(0xFF0A111E),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppColors.naranjaAccion, width: 1.5),
      ),
    ),
  );
}

class _MethodDropdown extends StatelessWidget {
  const _MethodDropdown({
    required this.value,
    required this.methods,
    required this.onChanged,
  });

  final String? value;
  final List<String> methods;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          style: AppTypography.bodyLarge,
          icon: const Icon(Icons.expand_more,
              color: AppColors.textoClaroMedio),
          items: methods.map((m) {
            final label = m[0].toUpperCase() + m.substring(1);
            return DropdownMenuItem(value: m, child: Text(label));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
