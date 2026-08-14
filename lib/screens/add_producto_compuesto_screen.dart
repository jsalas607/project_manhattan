import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';

// ---------------------------------------------------------------------------
// State holders (3 niveles)
// ---------------------------------------------------------------------------

/// Un ítem de inventario dentro de una opción.
class _ItemEntry {
  final cantCtrl = TextEditingController();
  InventoryItem? item;
  String?        newName;
  String         unidad = 'und';

  bool get seleccionado => item != null || newName != null;
  bool get esNuevo      => newName != null;

  void dispose() => cantCtrl.dispose();
}

/// Una opción dentro de un ingrediente (ej: "Pollo", "Carne de res").
class _OpcionEntry {
  final nombreCtrl           = TextEditingController();
  final List<_ItemEntry> items = [_ItemEntry()];

  void dispose() {
    nombreCtrl.dispose();
    for (final i in items) i.dispose();
  }
}

/// Un slot/ingrediente del producto (ej: "Proteína", "Aderezo").
class _IngredienteEntry {
  final nombreCtrl                 = TextEditingController();
  bool                obligatorio  = true;
  final List<_OpcionEntry> opciones = [_OpcionEntry()];

  /// Cuando hay 2+ opciones la mesera elige → obligatorio se deshabilita.
  bool get multiOpciones => opciones.length > 1;

  void dispose() {
    nombreCtrl.dispose();
    for (final o in opciones) o.dispose();
  }
}

// ---------------------------------------------------------------------------
// Pantalla principal
// ---------------------------------------------------------------------------

class AddProductoCompuestoScreen extends StatefulWidget {
  const AddProductoCompuestoScreen({
    super.key,
    required this.restaurant,
    required this.user,
    required this.onAdded,
  });

  final Restaurant              restaurant;
  final AppUser                 user;
  final void Function(Producto) onAdded;

  @override
  State<AddProductoCompuestoScreen> createState() =>
      _AddProductoCompuestoScreenState();
}

class _AddProductoCompuestoScreenState
    extends State<AddProductoCompuestoScreen> {
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  String? _catId;
  String? _catNombreNuevo;
  bool    _saving  = false;
  bool    _intento = false;

  List<Categoria>     _categorias = [];
  List<InventoryItem> _catalogo   = [];
  bool                _loading    = true;

  final List<_IngredienteEntry> _ingredientes = [];

  @override
  void initState() {
    super.initState();
    _ingredientes.add(_IngredienteEntry());
    _load();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    for (final ing in _ingredientes) ing.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cats = await MockCategoriasApi.getCategorias(widget.restaurant.id);
    final day  = await MockInventoryApi.getByDate(widget.restaurant.id, DateTime.now());
    if (!mounted) return;
    setState(() {
      _categorias = cats;
      _catalogo   = day.records.map((r) => r.item).toList();
      if (cats.isNotEmpty) _catId = cats.first.id;
      _loading    = false;
    });
  }

  // ── Mutaciones ──────────────────────────────────────────────────────────────

  void _agregarIngrediente() =>
      setState(() => _ingredientes.add(_IngredienteEntry()));

  void _eliminarIngrediente(int idx) {
    _ingredientes[idx].dispose();
    setState(() => _ingredientes.removeAt(idx));
  }

  void _agregarOpcion(int ingIdx) =>
      setState(() => _ingredientes[ingIdx].opciones.add(_OpcionEntry()));

  void _eliminarOpcion(int ingIdx, int opIdx) {
    _ingredientes[ingIdx].opciones[opIdx].dispose();
    setState(() => _ingredientes[ingIdx].opciones.removeAt(opIdx));
  }

  void _agregarItem(int ingIdx, int opIdx) =>
      setState(() =>
          _ingredientes[ingIdx].opciones[opIdx].items.add(_ItemEntry()));

  void _eliminarItem(int ingIdx, int opIdx, int itemIdx) {
    _ingredientes[ingIdx].opciones[opIdx].items[itemIdx].dispose();
    setState(() =>
        _ingredientes[ingIdx].opciones[opIdx].items.removeAt(itemIdx));
  }

  void _toggleObligatorio(int ingIdx) => setState(
      () => _ingredientes[ingIdx].obligatorio =
          !_ingredientes[ingIdx].obligatorio);

  // ── Validación ──────────────────────────────────────────────────────────────

  bool _validar() {
    if (_nombreCtrl.text.trim().isEmpty) return false;
    if (_precioCtrl.text.trim().isEmpty) return false;
    if (_catId == null && _catNombreNuevo == null) return false;
    for (final ing in _ingredientes) {
      for (final op in ing.opciones) {
        if (op.nombreCtrl.text.trim().isEmpty) return false;
        for (final item in op.items) {
          if (!item.seleccionado) return false;
        }
      }
    }
    return true;
  }

  // ── Guardar ─────────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() => _intento = true);
    if (!_validar()) return;
    setState(() => _saving = true);

    // Crear categoría nueva si el usuario la escribió
    if (_catNombreNuevo != null) {
      final nuevaCat = await MockCategoriasApi.addCategoria(
          widget.restaurant.id, _catNombreNuevo!);
      if (!mounted) return;
      _catId          = nuevaCat.id;
      _catNombreNuevo = null;
    }

    // Crear ítems nuevos de inventario
    for (final ing in _ingredientes) {
      for (final op in ing.opciones) {
        for (final itemEntry in op.items) {
          if (itemEntry.esNuevo) {
            final newItem = await MockInventoryApi.addItemToday(
                widget.restaurant.id, name: itemEntry.newName!, unidad: itemEntry.unidad);
            if (!mounted) return;
            itemEntry.item    = newItem;
            itemEntry.newName = null;
          }
        }
      }
    }

    // Construir la receta: cada ingrediente con sus opciones
    // obligatorio efectivo = el toggle está ON y solo hay 1 opción
    // (con 2+ opciones la mesera elige → nunca es obligatorio)
    final ingredientes = _ingredientes.map((ing) {
      return IngredienteReceta(
        nombre:      ing.nombreCtrl.text.trim(),
        obligatorio: ing.obligatorio && !ing.multiOpciones,
        opciones: ing.opciones
            .map((op) => OpcionReceta(nombre: op.nombreCtrl.text.trim()))
            .toList(),
      );
    }).toList();

    final precio = double.tryParse(_precioCtrl.text.trim()) ?? 0;
    final producto = await MockMenuApi.addProducto(
      widget.restaurant.id,
      nombre:       _nombreCtrl.text.trim(),
      precio:       precio,
      categoriaId:  _catId!,
      ingredientes: ingredientes,
    );
    if (!mounted) return;
    widget.onAdded(producto);
    Navigator.pop(context);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

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
        title: Text('Producto compuesto', style: AppTypography.titleLarge),
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
                  // Usuario + sucursal
                  RestaurantHeader(
                      restaurant: widget.restaurant, user: widget.user),
                  const SizedBox(height: 24),

                  // Nombre
                  _LabeledField(
                    label: 'Nombre del producto',
                    child: _buildTextField(
                      ctrl:      _nombreCtrl,
                      hint:      'Ej: Hamburguesa, Almuerzo, Arepa...',
                      error:     _intento &&
                          _nombreCtrl.text.trim().isEmpty,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Precio + Categoría
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _LabeledField(
                          label: 'Precio',
                          child: _buildTextField(
                            ctrl:      _precioCtrl,
                            hint:      '0',
                            error:     _intento &&
                                _precioCtrl.text.trim().isEmpty,
                            numeric:   true,
                            onChanged: () => setState(() {}),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LabeledField(
                          label: 'Categoría',
                          child: _CatSelectorField(
                            categorias:     _categorias,
                            catId:          _catId,
                            catNombreNuevo: _catNombreNuevo,
                            error: _intento &&
                                _catId == null &&
                                _catNombreNuevo == null,
                            onChanged: (id, nombre) => setState(() {
                              _catId          = id;
                              _catNombreNuevo = nombre;
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Encabezado ingredientes
                  Row(
                    children: [
                      const Icon(Icons.restaurant_menu,
                          color: AppColors.naranjaAccion, size: 18),
                      const SizedBox(width: 8),
                      Text('Ingredientes',
                          style: AppTypography.labelLarge),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cada ingrediente puede tener una o varias opciones para que la mesera elija.',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textoClaroMedio),
                  ),
                  const SizedBox(height: 14),

                  // Lista de ingredientes
                  ...List.generate(_ingredientes.length, (ingIdx) {
                    final ing = _ingredientes[ingIdx];
                    return Padding(
                      key: ObjectKey(ing),
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _IngredienteCard(
                        entry:    ing,
                        index:    ingIdx,
                        catalogo: _catalogo,
                        intento:  _intento,
                        canDelete: _ingredientes.length > 1,
                        onChanged:  () => setState(() {}),
                        onEliminar: () => _eliminarIngrediente(ingIdx),
                        onToggleObligatorio: () =>
                            _toggleObligatorio(ingIdx),
                        onAgregarOpcion: () => _agregarOpcion(ingIdx),
                        onEliminarOpcion: (opIdx) =>
                            _eliminarOpcion(ingIdx, opIdx),
                        onAgregarItem: (opIdx) =>
                            _agregarItem(ingIdx, opIdx),
                        onEliminarItem: (opIdx, itemIdx) =>
                            _eliminarItem(ingIdx, opIdx, itemIdx),
                      ),
                    );
                  }),

                  // Añadir otro ingrediente
                  OutlinedButton.icon(
                    onPressed: _agregarIngrediente,
                    icon: const Icon(Icons.add,
                        color: AppColors.naranjaAccion, size: 18),
                    label: Text(
                      'Añadir otro ingrediente',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.naranjaAccion),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.naranjaAccion
                              .withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Guardar
                  ElevatedButton(
                    onPressed: _saving ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.naranjaAccion,
                      disabledBackgroundColor:
                          AppColors.naranjaAccion.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : Text('GUARDAR',
                            style: AppTypography.labelLarge.copyWith(
                                color: AppColors.textoClaroAlto)),
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de ingrediente
// ---------------------------------------------------------------------------

class _IngredienteCard extends StatelessWidget {
  const _IngredienteCard({
    required this.entry,
    required this.index,
    required this.catalogo,
    required this.intento,
    required this.canDelete,
    required this.onChanged,
    required this.onEliminar,
    required this.onToggleObligatorio,
    required this.onAgregarOpcion,
    required this.onEliminarOpcion,
    required this.onAgregarItem,
    required this.onEliminarItem,
  });

  final _IngredienteEntry       entry;
  final int                     index;
  final List<InventoryItem>     catalogo;
  final bool                    intento;
  final bool                    canDelete;
  final VoidCallback            onChanged;
  final VoidCallback            onEliminar;
  final VoidCallback            onToggleObligatorio;
  final VoidCallback            onAgregarOpcion;
  final void Function(int)      onEliminarOpcion;
  final void Function(int)      onAgregarItem;
  final void Function(int, int) onEliminarItem;

  @override
  Widget build(BuildContext context) {
    final disabled = entry.multiOpciones;
    // El toggle se muestra "encendido" solo si: no está deshabilitado Y obligatorio es true
    final toggleOn = entry.obligatorio && !disabled;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.naranjaAccion.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: AppColors.naranjaAccion.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Etiqueta + X
                Row(
                  children: [
                    Text(
                      'Ingrediente ${index + 1}',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.naranjaAccion,
                          fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (canDelete)
                      GestureDetector(
                        onTap: onEliminar,
                        child: const Icon(Icons.close,
                            size: 16, color: AppColors.rojoAlerta),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Nombre + toggle obligatorio
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        ctrl:      entry.nombreCtrl,
                        hint:      'Ej: Proteína, Aderezo, Pan...',
                        fillColor: const Color(0xFF0F172A),
                        onChanged: onChanged,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Toggle obligatorio
                    Opacity(
                      opacity: disabled ? 0.38 : 1.0,
                      child: GestureDetector(
                        onTap: disabled ? null : onToggleObligatorio,
                        child: Column(
                          children: [
                            Text(
                              'Obligatorio',
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.textoClaroMedio,
                                  fontSize: 10),
                            ),
                            const SizedBox(height: 5),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width:  42,
                              height: 24,
                              decoration: BoxDecoration(
                                color: toggleOn
                                    ? AppColors.verdeExito
                                    : const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: AnimatedAlign(
                                duration:
                                    const Duration(milliseconds: 200),
                                alignment: toggleOn
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.all(3),
                                  width:  18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Nota cuando está deshabilitado
                if (disabled) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 12, color: AppColors.textoClaroMedio),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Tiene varias opciones — la mesera elige cuál se descuenta.',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.textoClaroMedio,
                              fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Opciones ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...List.generate(entry.opciones.length, (opIdx) {
                  return Padding(
                    key: ObjectKey(entry.opciones[opIdx]),
                    padding: EdgeInsets.only(
                        bottom:
                            opIdx < entry.opciones.length - 1 ? 12 : 0),
                    child: _OpcionCard(
                      entry:    entry.opciones[opIdx],
                      index:    opIdx,
                      catalogo: catalogo,
                      intento:  intento,
                      canDelete: entry.opciones.length > 1,
                      onChanged:      onChanged,
                      onEliminar:     () => onEliminarOpcion(opIdx),
                      onAgregarItem:  () => onAgregarItem(opIdx),
                      onEliminarItem: (itemIdx) =>
                          onEliminarItem(opIdx, itemIdx),
                    ),
                  );
                }),
                const SizedBox(height: 12),

                // Añadir otra opción
                OutlinedButton.icon(
                  onPressed: onAgregarOpcion,
                  icon: const Icon(Icons.add,
                      color: AppColors.azulControl, size: 16),
                  label: Text(
                    'Añadir otra opción',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.azulControl),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color:
                            AppColors.azulControl.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de opción
// ---------------------------------------------------------------------------

class _OpcionCard extends StatelessWidget {
  const _OpcionCard({
    required this.entry,
    required this.index,
    required this.catalogo,
    required this.intento,
    required this.canDelete,
    required this.onChanged,
    required this.onEliminar,
    required this.onAgregarItem,
    required this.onEliminarItem,
  });

  final _OpcionEntry        entry;
  final int                 index;
  final List<InventoryItem> catalogo;
  final bool                intento;
  final bool                canDelete;
  final VoidCallback        onChanged;
  final VoidCallback        onEliminar;
  final VoidCallback        onAgregarItem;
  final void Function(int)  onEliminarItem;

  static const _letras = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

  @override
  Widget build(BuildContext context) {
    final letra = index < _letras.length ? _letras[index] : '${index + 1}';
    final nombreVacio = intento && entry.nombreCtrl.text.trim().isEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.azulControl.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header opción: chip "Opción A" + nombre + X
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.azulControl.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Opción $letra',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.azulControl,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  ctrl:  entry.nombreCtrl,
                  hint:  'Ej: Pollo, Carne, Vinagreta...',
                  error: nombreVacio,
                  onChanged: onChanged,
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onEliminar,
                  child: const Icon(Icons.close,
                      size: 16, color: AppColors.rojoAlerta),
                ),
              ],
            ],
          ),
          if (nombreVacio) ...[
            const SizedBox(height: 4),
            Text(
              'Nombre obligatorio',
              style: AppTypography.caption
                  .copyWith(color: AppColors.rojoAlerta),
            ),
          ],
          const SizedBox(height: 12),

          // Ítems de inventario
          ...List.generate(entry.items.length, (itemIdx) {
            final itemEntry = entry.items[itemIdx];
            return Padding(
              key: ObjectKey(itemEntry),
              padding: EdgeInsets.only(
                  bottom: itemIdx < entry.items.length - 1 ? 14 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Separador entre ítems
                  if (itemIdx > 0) ...[
                    Divider(
                      height: 1,
                      color: AppColors.azulControl.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Selector + X eliminar ítem
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ItemSelectorField(
                          catalogo:         catalogo,
                          entry:            itemEntry,
                          intento:          intento,
                          onChanged:        onChanged,
                          sugerenciaNombre: entry.nombreCtrl.text.trim(),
                        ),
                      ),
                      if (entry.items.length > 1) ...[
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(top: 11),
                          child: GestureDetector(
                            onTap: () => onEliminarItem(itemIdx),
                            child: const Icon(
                                Icons.remove_circle_outline,
                                size: 18,
                                color: AppColors.rojoAlerta),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Cantidad + unidad (si hay ítem seleccionado)
                  if (itemEntry.seleccionado) ...[
                    const SizedBox(height: 8),
                    _ItemCantUnidadRow(
                        entry: itemEntry, onChanged: onChanged),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 12),

          // Botón "Añadir ingrediente" (añade otro ítem de inventario)
          GestureDetector(
            onTap: onAgregarItem,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.add_circle_outline,
                    size: 14, color: AppColors.azulControl),
                const SizedBox(width: 5),
                Text(
                  'Añadir ingrediente',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.azulControl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Campo autocomplete de inventario (para producto compuesto)
// ---------------------------------------------------------------------------

class _ItemSelectorField extends StatefulWidget {
  const _ItemSelectorField({
    required this.catalogo,
    required this.entry,
    required this.intento,
    required this.onChanged,
    this.sugerenciaNombre = '',
  });

  final List<InventoryItem> catalogo;
  final _ItemEntry          entry;
  final bool                intento;
  final VoidCallback        onChanged;
  final String              sugerenciaNombre;

  @override
  State<_ItemSelectorField> createState() => _ItemSelectorFieldState();
}

class _ItemSelectorFieldState extends State<_ItemSelectorField> {
  final _ctrl = TextEditingController();
  String _lastSug = '';

  @override
  void initState() {
    super.initState();
    if (widget.sugerenciaNombre.isNotEmpty) {
      _ctrl.text = widget.sugerenciaNombre;
      _lastSug   = widget.sugerenciaNombre;
    }
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(_ItemSelectorField old) {
    super.didUpdateWidget(old);
    final newSug = widget.sugerenciaNombre;
    if (newSug != old.sugerenciaNombre &&
        !widget.entry.seleccionado &&
        _ctrl.text == _lastSug) {
      _ctrl.text = newSug;
      _lastSug   = newSug;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<InventoryItem> get _sugs {
    final q = _ctrl.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    return widget.catalogo
        .where((i) => i.name.toLowerCase().contains(q))
        .toList();
  }

  bool get _exactMatch => widget.catalogo.any(
      (i) => i.name.toLowerCase() == _ctrl.text.trim().toLowerCase());

  void _selectItem(InventoryItem item) {
    _ctrl.text           = item.name;
    widget.entry.item    = item;
    widget.entry.newName = null;
    widget.entry.unidad  = item.unidad;
    widget.onChanged();
  }

  void _selectNuevo() {
    final nombre = _ctrl.text.trim();
    if (nombre.isEmpty) return;
    widget.entry.item    = null;
    widget.entry.newName = nombre;
    widget.onChanged();
  }

  void _limpiar() {
    _ctrl.clear();
    _lastSug             = '';
    widget.entry.item    = null;
    widget.entry.newName = null;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final q      = _ctrl.text.trim();
    final sinSel = widget.intento && !widget.entry.seleccionado;
    final sugs   = _sugs;

    final showSugs  = q.isNotEmpty && sugs.isNotEmpty &&
        !widget.entry.seleccionado;
    final showCrear = q.isNotEmpty && !_exactMatch &&
        !widget.entry.seleccionado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          style:      AppTypography.bodyMedium,
          onChanged:  (_) {
            widget.entry.item    = null;
            widget.entry.newName = null;
            widget.onChanged();
          },
          decoration: InputDecoration(
            hintText: 'Buscar en inventario...',
            hintStyle: AppTypography.caption.copyWith(
                color: AppColors.textoClaroMedio.withValues(alpha: 0.4)),
            prefixIcon: const Icon(Icons.search,
                size: 18, color: AppColors.textoClaroMedio),
            suffixIcon: (widget.entry.seleccionado || q.isNotEmpty)
                ? GestureDetector(
                    onTap: _limpiar,
                    child: Icon(
                      widget.entry.seleccionado
                          ? (widget.entry.esNuevo
                              ? Icons.add_circle
                              : Icons.check_circle)
                          : Icons.close,
                      color: widget.entry.seleccionado
                          ? (widget.entry.esNuevo
                              ? AppColors.verdeExito
                              : AppColors.azulControl)
                          : AppColors.textoClaroMedio,
                      size: 18,
                    ),
                  )
                : null,
            filled:    true,
            fillColor: const Color(0xFF1E293B),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: sinSel
                    ? AppColors.rojoAlerta
                    : AppColors.azulControl.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: sinSel
                    ? AppColors.rojoAlerta
                    : AppColors.naranjaAccion,
              ),
            ),
          ),
        ),

        if (sinSel) ...[
          const SizedBox(height: 4),
          Text('Selecciona o crea un ítem del inventario',
              style: AppTypography.caption
                  .copyWith(color: AppColors.rojoAlerta)),
        ],

        if (showSugs)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.azulControl.withValues(alpha: 0.3)),
            ),
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: Column(
                children: sugs
                    .map((item) => _SugItem(
                          label: item.name,
                          sub:   item.unidad,
                          icon:  Icons.inventory_2_outlined,
                          color: AppColors.azulControl,
                          onTap: () => _selectItem(item),
                        ))
                    .toList(),
              ),
            ),
          ),

        if (showCrear)
          GestureDetector(
            onTap: _selectNuevo,
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.verdeExito.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.verdeExito.withValues(alpha: 0.35)),
              ),
              child: Row(children: [
                const Icon(Icons.add_circle_outline,
                    color: AppColors.verdeExito, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Crear "$q" en inventario',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.verdeExito),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.verdeExito, size: 18),
              ]),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fila de cantidad + unidad de medida
// ---------------------------------------------------------------------------

const _kUnidades = ['und', 'kg', 'gr', 'lt', 'ml'];

class _ItemCantUnidadRow extends StatelessWidget {
  const _ItemCantUnidadRow(
      {required this.entry, required this.onChanged});
  final _ItemEntry   entry;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Badge: nuevo en inventario
        if (entry.esNuevo)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.verdeExito.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.verdeExito.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.add_circle_outline,
                  color: AppColors.verdeExito, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Nuevo en inventario: "${entry.newName}"',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.verdeExito),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),

        // Cantidad + unidad
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Cantidad a descontar',
                child: _buildTextField(
                  ctrl:      entry.cantCtrl,
                  hint:      '1',
                  numeric:   true,
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unidad',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textoClaroMedio)),
                  const SizedBox(height: 6),
                  if (entry.esNuevo)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.azulControl
                                .withValues(alpha: 0.4)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value:            entry.unidad,
                          isDense:          true,
                          isExpanded:       true,
                          dropdownColor:    const Color(0xFF1E293B),
                          style:            AppTypography.bodyMedium,
                          iconEnabledColor: AppColors.textoClaroMedio,
                          items: _kUnidades
                              .map((u) => DropdownMenuItem(
                                    value: u, child: Text(u)))
                              .toList(),
                          onChanged: (u) {
                            if (u != null) {
                              entry.unidad = u;
                              onChanged();
                            }
                          },
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.azulControl
                                .withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        entry.unidad,
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.azulControl),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ítem de sugerencia
// ---------------------------------------------------------------------------

class _SugItem extends StatelessWidget {
  const _SugItem({
    required this.label,
    required this.sub,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String       label;
  final String       sub;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label,
                    style: AppTypography.bodyMedium,
                    overflow: TextOverflow.ellipsis)),
            Text(sub,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textoClaroMedio)),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------
// Selector de categoría con autocomplete y creación al vuelo
// ---------------------------------------------------------------------------

class _CatSelectorField extends StatefulWidget {
  const _CatSelectorField({
    required this.categorias,
    required this.catId,
    required this.catNombreNuevo,
    required this.error,
    required this.onChanged,
  });

  final List<Categoria> categorias;
  final String?         catId;
  final String?         catNombreNuevo;
  final bool            error;
  final void Function(String? catId, String? catNombreNuevo) onChanged;

  @override
  State<_CatSelectorField> createState() => _CatSelectorFieldState();
}

class _CatSelectorFieldState extends State<_CatSelectorField> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.catId != null) {
      try {
        final cat =
            widget.categorias.firstWhere((c) => c.id == widget.catId);
        _ctrl.text = cat.nombre;
      } catch (_) {}
    } else if (widget.catNombreNuevo != null) {
      _ctrl.text = widget.catNombreNuevo!;
    }
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _seleccionada =>
      widget.catId != null || widget.catNombreNuevo != null;
  bool get _esNueva => widget.catNombreNuevo != null;

  List<Categoria> get _sugs {
    final q = _ctrl.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    return widget.categorias
        .where((c) => c.nombre.toLowerCase().contains(q))
        .toList();
  }

  bool get _exactMatch => widget.categorias.any(
      (c) => c.nombre.toLowerCase() == _ctrl.text.trim().toLowerCase());

  void _selectExisting(Categoria cat) {
    _ctrl.text = cat.nombre;
    widget.onChanged(cat.id, null);
  }

  void _selectNueva() {
    final nombre = _ctrl.text.trim();
    if (nombre.isEmpty) return;
    widget.onChanged(null, nombre);
  }

  void _limpiar() {
    _ctrl.clear();
    widget.onChanged(null, null);
  }

  @override
  Widget build(BuildContext context) {
    final q      = _ctrl.text.trim();
    final sinSel = widget.error && !_seleccionada;
    final sugs   = _sugs;

    final showSugs  = q.isNotEmpty && sugs.isNotEmpty && !_seleccionada;
    final showCrear = q.isNotEmpty && !_exactMatch && !_seleccionada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          style:      AppTypography.bodyMedium,
          onChanged:  (_) => widget.onChanged(null, null),
          decoration: InputDecoration(
            hintText: 'Buscar o crear categoría...',
            hintStyle: AppTypography.caption.copyWith(
                color: AppColors.textoClaroMedio.withValues(alpha: 0.4)),
            prefixIcon: const Icon(Icons.category_outlined,
                size: 18, color: AppColors.textoClaroMedio),
            suffixIcon: (_seleccionada || q.isNotEmpty)
                ? GestureDetector(
                    onTap: _limpiar,
                    child: Icon(
                      _seleccionada
                          ? (_esNueva
                              ? Icons.add_circle
                              : Icons.check_circle)
                          : Icons.close,
                      color: _seleccionada
                          ? (_esNueva
                              ? const Color(0xFF8B5CF6)
                              : AppColors.azulControl)
                          : AppColors.textoClaroMedio,
                      size: 18,
                    ),
                  )
                : null,
            filled:    true,
            fillColor: const Color(0xFF1E293B),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: sinSel
                    ? AppColors.rojoAlerta
                    : AppColors.azulControl.withValues(alpha: 0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: sinSel
                    ? AppColors.rojoAlerta
                    : AppColors.naranjaAccion,
              ),
            ),
          ),
        ),
        if (sinSel) ...[
          const SizedBox(height: 4),
          Text('Selecciona o crea una categoría',
              style: AppTypography.caption
                  .copyWith(color: AppColors.rojoAlerta)),
        ],

        // Sugerencias de categorías existentes
        if (showSugs)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.azulControl.withValues(alpha: 0.3)),
            ),
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Column(
                children: sugs
                    .map((cat) => _SugItem(
                          label: cat.nombre,
                          sub:   '',
                          icon:  Icons.category_outlined,
                          color: const Color(0xFF8B5CF6),
                          onTap: () => _selectExisting(cat),
                        ))
                    .toList(),
              ),
            ),
          ),

        // Crear nueva categoría
        if (showCrear)
          GestureDetector(
            onTap: _selectNueva,
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF8B5CF6)
                        .withValues(alpha: 0.35)),
              ),
              child: Row(children: [
                const Icon(Icons.add_circle_outline,
                    color: Color(0xFF8B5CF6), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Crear categoría "$q"',
                    style: AppTypography.bodyMedium
                        .copyWith(color: const Color(0xFF8B5CF6)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF8B5CF6), size: 18),
              ]),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers de layout
// ---------------------------------------------------------------------------

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

Widget _buildTextField({
  required TextEditingController ctrl,
  required String                hint,
  bool                           error     = false,
  bool                           numeric   = false,
  Color                          fillColor = const Color(0xFF1E293B),
  required VoidCallback          onChanged,
}) =>
    TextField(
      controller:      ctrl,
      onChanged:       (_) => onChanged(),
      style:           AppTypography.bodyMedium,
      keyboardType:    numeric
          ? TextInputType.number
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: AppTypography.caption.copyWith(
            color: AppColors.textoClaroMedio.withValues(alpha: 0.4)),
        filled:    true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 13),
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
            color: error
                ? AppColors.rojoAlerta
                : AppColors.naranjaAccion,
          ),
        ),
      ),
    );

