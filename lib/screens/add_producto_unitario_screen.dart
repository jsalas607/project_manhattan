import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';

// ---------------------------------------------------------------------------
// State holder para cada entrada de inventario
// ---------------------------------------------------------------------------

class _InventarioEntry {
  final varNombreCtrl = TextEditingController();
  final cantCtrl      = TextEditingController();
  InventoryItem? item;
  String?        newName;
  String         unidad = 'und';

  bool get seleccionado => item != null || newName != null;
  bool get esNuevo      => newName != null;

  void dispose() {
    varNombreCtrl.dispose();
    cantCtrl.dispose();
  }
}

// ---------------------------------------------------------------------------
// Pantalla principal
// ---------------------------------------------------------------------------

class AddProductoUnitarioScreen extends StatefulWidget {
  const AddProductoUnitarioScreen({
    super.key,
    required this.restaurant,
    required this.user,
    required this.onAdded,
  });

  final Restaurant              restaurant;
  final AppUser                 user;
  final void Function(Producto) onAdded;

  @override
  State<AddProductoUnitarioScreen> createState() =>
      _AddProductoUnitarioScreenState();
}

class _AddProductoUnitarioScreenState
    extends State<AddProductoUnitarioScreen> {
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  String? _catId;
  bool    _tieneVariantes = false;
  bool    _saving  = false;
  bool    _intento = false;

  List<Categoria>     _categorias = [];
  List<InventoryItem> _catalogo   = [];
  bool                _loading    = true;

  final _sinVarEntry               = _InventarioEntry();
  final List<_InventarioEntry> _varEntries = [];

  @override
  void initState() {
    super.initState();
    // Mínimo 2 variantes para que tenga sentido activar la opción
    _varEntries.add(_InventarioEntry());
    _varEntries.add(_InventarioEntry());
    _load();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _sinVarEntry.dispose();
    for (final e in _varEntries) {
      e.dispose();
    }
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

  void _agregarVariante() =>
      setState(() => _varEntries.add(_InventarioEntry()));

  void _eliminarVariante(int idx) {
    _varEntries[idx].dispose();
    setState(() => _varEntries.removeAt(idx));
  }

  bool _validar() {
    if (_nombreCtrl.text.trim().isEmpty) return false;
    if (_precioCtrl.text.trim().isEmpty) return false;
    if (_catId == null) return false;
    final entries = _tieneVariantes ? _varEntries : [_sinVarEntry];
    for (final e in entries) {
      if (_tieneVariantes && e.varNombreCtrl.text.trim().isEmpty) return false;
      if (!e.seleccionado) return false;
    }
    return true;
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() => _intento = true);
    if (!_validar()) return;
    setState(() => _saving = true);

    final entries = _tieneVariantes ? _varEntries : [_sinVarEntry];
    final precio  = double.tryParse(_precioCtrl.text.trim()) ?? 0;

    for (final entry in entries) {
      if (entry.esNuevo) {
        final item = await MockInventoryApi.addItemToday(
            widget.restaurant.id, name: entry.newName!, unidad: entry.unidad);
        if (!mounted) return;
        entry.item    = item;
        entry.newName = null;
      }
      final nombre = _tieneVariantes
          ? '${_nombreCtrl.text.trim()} ${entry.varNombreCtrl.text.trim()}'
          : _nombreCtrl.text.trim();

      final producto = await MockMenuApi.addProducto(
        widget.restaurant.id,
        nombre:      nombre,
        precio:      precio,
        categoriaId: _catId!,
      );
      if (!mounted) return;
      widget.onAdded(producto);
    }
    if (!mounted) return;
    Navigator.pop(context);
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
        title: Text('Producto unitario', style: AppTypography.titleLarge),
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

                  // Foto + Nombre / solo Nombre
                  if (!_tieneVariantes)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Foto',
                                style: AppTypography.caption.copyWith(
                                    color: AppColors.textoClaroMedio)),
                            const SizedBox(height: 6),
                            const _FotoPicker(),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _LabeledField(
                            label: 'Nombre del producto',
                            child: _buildTextField(
                              ctrl:    _nombreCtrl,
                              hint:    'Ej: Agua, Coca-Cola...',
                              error:   _intento &&
                                  _nombreCtrl.text.trim().isEmpty,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    _LabeledField(
                      label: 'Nombre del producto',
                      child: _buildTextField(
                        ctrl:    _nombreCtrl,
                        hint:    'Ej: Coca-Cola, Cerveza...',
                        error:   _intento &&
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
                            ctrl:  _precioCtrl,
                            hint:  '0',
                            error: _intento &&
                                _precioCtrl.text.trim().isEmpty,
                            numeric: true,
                            onChanged: () => setState(() {}),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LabeledField(
                          label: 'Categoría',
                          child: _CatDropdown(
                            categorias: _categorias,
                            catId:      _catId,
                            error:      _intento && _catId == null,
                            onChanged:  (id) =>
                                setState(() => _catId = id),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Checkbox variantes
                  GestureDetector(
                    onTap: () => setState(
                        () => _tieneVariantes = !_tieneVariantes),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: _tieneVariantes
                              ? AppColors.naranjaAccion
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _tieneVariantes
                                ? AppColors.naranjaAccion
                                : AppColors.textoClaroMedio
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                        child: _tieneVariantes
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text('Este producto tiene variantes',
                          style: AppTypography.bodyMedium),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Sección inventario
                  if (!_tieneVariantes)
                    _InventarioSection(
                      entry:          _sinVarEntry,
                      catalogo:       _catalogo,
                      intento:        _intento,
                      onChanged:      () => setState(() {}),
                      nombreProducto: _nombreCtrl.text.trim(),
                    )
                  else
                    _VariantesSection(
                      entries:    _varEntries,
                      nombreBase: _nombreCtrl.text.trim(),
                      catalogo:   _catalogo,
                      intento:    _intento,
                      onChanged:  () => setState(() {}),
                      onAgregar:  _agregarVariante,
                      onEliminar: _eliminarVariante,
                    ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _saving ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.naranjaAccion,
                      disabledBackgroundColor:
                          AppColors.naranjaAccion.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('GUARDAR',
                            style: AppTypography.labelLarge
                                .copyWith(color: AppColors.textoClaroAlto)),
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sección sin variantes
// ---------------------------------------------------------------------------

class _InventarioSection extends StatelessWidget {
  const _InventarioSection({
    required this.entry,
    required this.catalogo,
    required this.intento,
    required this.onChanged,
    required this.nombreProducto,
  });

  final _InventarioEntry    entry;
  final List<InventoryItem> catalogo;
  final bool                intento;
  final VoidCallback        onChanged;
  final String              nombreProducto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ítem del inventario', style: AppTypography.labelLarge),
        const SizedBox(height: 4),
        Text(
          'Selecciona del inventario, o escribe un nombre nuevo para crearlo.',
          style: AppTypography.caption
              .copyWith(color: AppColors.textoClaroMedio),
        ),
        const SizedBox(height: 10),
        _InventarioSelectorField(
          catalogo:         catalogo,
          entry:            entry,
          intento:          intento,
          onChanged:        onChanged,
          sugerenciaNombre: nombreProducto,
        ),
        if (entry.seleccionado) ...[
          const SizedBox(height: 10),
          _UnidadCantidadRow(entry: entry, onChanged: onChanged),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sección con variantes
// ---------------------------------------------------------------------------

class _VariantesSection extends StatelessWidget {
  const _VariantesSection({
    required this.entries,
    required this.nombreBase,
    required this.catalogo,
    required this.intento,
    required this.onChanged,
    required this.onAgregar,
    required this.onEliminar,
  });

  final List<_InventarioEntry> entries;
  final String                 nombreBase;
  final List<InventoryItem>    catalogo;
  final bool                   intento;
  final VoidCallback           onChanged;
  final VoidCallback           onAgregar;
  final void Function(int)     onEliminar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Variantes', style: AppTypography.labelLarge),
        const SizedBox(height: 4),
        Text(
          'El nombre de cada variante se une al nombre principal.',
          style: AppTypography.caption
              .copyWith(color: AppColors.textoClaroMedio),
        ),
        const SizedBox(height: 12),
        ...List.generate(entries.length, (i) => Padding(
          key: ObjectKey(entries[i]),
          padding: const EdgeInsets.only(bottom: 12),
          child: _VarianteCard(
            entry:      entries[i],
            index:      i,
            nombreBase: nombreBase,
            catalogo:   catalogo,
            intento:    intento,
            onChanged:  onChanged,
            canDelete:  entries.length > 2,
            onEliminar: () => onEliminar(i),
          ),
        )),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: onAgregar,
          icon:  const Icon(Icons.add,
              color: AppColors.naranjaAccion, size: 18),
          label: Text('Añadir otro',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.naranjaAccion)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
                color: AppColors.naranjaAccion.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _VarianteCard extends StatelessWidget {
  const _VarianteCard({
    required this.entry,
    required this.index,
    required this.nombreBase,
    required this.catalogo,
    required this.intento,
    required this.onChanged,
    required this.canDelete,
    required this.onEliminar,
  });

  final _InventarioEntry    entry;
  final int                 index;
  final String              nombreBase;
  final List<InventoryItem> catalogo;
  final bool                intento;
  final VoidCallback        onChanged;
  final bool                canDelete;
  final VoidCallback        onEliminar;

  @override
  Widget build(BuildContext context) {
    final nombreVacio =
        intento && entry.varNombreCtrl.text.trim().isEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.azulControl.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header variante
          Row(
            children: [
              Text('Variante ${index + 1}',
                  style: AppTypography.labelLarge),
              const SizedBox(width: 6),
              Tooltip(
                message: nombreBase.isEmpty
                    ? 'El nombre se concatena con el nombre principal'
                    : 'Nombre completo: "$nombreBase [variante]"',
                child: const Icon(Icons.info_outline,
                    size: 14,
                    color: AppColors.textoClaroMedio),
              ),
              const Spacer(),
              if (canDelete)
                GestureDetector(
                  onTap: onEliminar,
                  child: const Icon(Icons.close,
                      size: 18, color: AppColors.rojoAlerta),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Nombre variante
          _buildTextField(
            ctrl:  entry.varNombreCtrl,
            hint:  'Ej: Original, Zero, 350ml...',
            error: nombreVacio,
            onChanged: onChanged,
          ),
          if (nombreVacio) ...[
            const SizedBox(height: 4),
            Text('Campo obligatorio',
                style: AppTypography.caption
                    .copyWith(color: AppColors.rojoAlerta)),
          ],
          const SizedBox(height: 12),

          // Inventario — sugerencia = nombre base + nombre variante
          _InventarioSelectorField(
            catalogo:         catalogo,
            entry:            entry,
            intento:          intento,
            onChanged:        onChanged,
            sugerenciaNombre: '${nombreBase.isEmpty ? '' : '$nombreBase '}'
                '${entry.varNombreCtrl.text}'.trim(),
          ),
          if (entry.seleccionado) ...[
            const SizedBox(height: 10),
            _UnidadCantidadRow(entry: entry, onChanged: onChanged),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Autocomplete de inventario
// ---------------------------------------------------------------------------

class _InventarioSelectorField extends StatefulWidget {
  const _InventarioSelectorField({
    required this.catalogo,
    required this.entry,
    required this.intento,
    required this.onChanged,
    this.sugerenciaNombre = '',
  });

  final List<InventoryItem> catalogo;
  final _InventarioEntry    entry;
  final bool                intento;
  final VoidCallback        onChanged;
  /// Nombre sugerido para pre-llenar el campo (producto [+ variante]).
  final String              sugerenciaNombre;

  @override
  State<_InventarioSelectorField> createState() =>
      _InventarioSelectorFieldState();
}

class _InventarioSelectorFieldState
    extends State<_InventarioSelectorField> {
  final _ctrl = TextEditingController();
  /// Último valor que auto-aplicamos; permite detectar ediciones manuales.
  String _lastSug = '';

  @override
  void initState() {
    super.initState();
    // Pre-llenar con la sugerencia inicial si existe
    if (widget.sugerenciaNombre.isNotEmpty) {
      _ctrl.text = widget.sugerenciaNombre;
      _lastSug   = widget.sugerenciaNombre;
    }
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(_InventarioSelectorField old) {
    super.didUpdateWidget(old);
    final newSug = widget.sugerenciaNombre;
    // Sincronizar solo si:
    // • la sugerencia cambió
    // • no hay ítem seleccionado todavía
    // • el usuario no editó manualmente el campo (texto == último auto-aplicado)
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
    _lastSug             = '';   // reset para que el próximo didUpdateWidget pueda auto-llenar
    widget.entry.item    = null;
    widget.entry.newName = null;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final q       = _ctrl.text.trim();
    final sinSel  = widget.intento && !widget.entry.seleccionado;
    final sugs    = _sugs;

    // Mostrar sugerencias de ítems existentes cuando hay texto y no hay nada seleccionado
    final showSugs  = q.isNotEmpty && sugs.isNotEmpty && !widget.entry.seleccionado;
    // Mostrar botón "Crear en inventario" cuando hay texto, no hay coincidencia exacta
    // y no hay nada seleccionado
    final showCrear = q.isNotEmpty && !_exactMatch && !widget.entry.seleccionado;

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

        // Error de validación
        if (sinSel) ...[
          const SizedBox(height: 4),
          Text('Selecciona o crea un ítem del inventario',
              style: AppTypography.caption
                  .copyWith(color: AppColors.rojoAlerta)),
        ],

        // Lista de ítems existentes que coinciden
        if (showSugs)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.azulControl.withValues(alpha: 0.3)),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
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

        // Botón "Crear en inventario" — siempre visible cuando aplica
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
// Unidad de medida + Cantidad a descontar
// ---------------------------------------------------------------------------

const _unidades = ['und', 'kg', 'gr', 'lt', 'ml'];

class _UnidadCantidadRow extends StatelessWidget {
  const _UnidadCantidadRow(
      {required this.entry, required this.onChanged});
  final _InventarioEntry entry;
  final VoidCallback     onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Badge: nuevo en inventario
        if (entry.esNuevo)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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

        // Cantidad + Unidad lado a lado
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cantidad
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

            // Unidad
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unidad',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.textoClaroMedio)),
                  const SizedBox(height: 6),
                  if (entry.esNuevo)
                    // Editable si es ítem nuevo
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                AppColors.azulControl.withValues(alpha: 0.4)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value:     entry.unidad,
                          isDense:   true,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          style:     AppTypography.bodyMedium,
                          iconEnabledColor: AppColors.textoClaroMedio,
                          items: _unidades
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u)))
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
                    // Solo lectura si ítem ya existe
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                AppColors.azulControl.withValues(alpha: 0.2)),
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
// Selector de categoría — lista desplegable (solo seleccionar existentes)
// ---------------------------------------------------------------------------

class _CatDropdown extends StatelessWidget {
  const _CatDropdown({
    required this.categorias,
    required this.catId,
    required this.error,
    required this.onChanged,
  });

  final List<Categoria>       categorias;
  final String?               catId;
  final bool                  error;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: error
                  ? AppColors.rojoAlerta
                  : AppColors.azulControl.withValues(alpha: 0.4),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value:      catId,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E293B),
              style:      AppTypography.bodyMedium,
              icon: const Icon(Icons.expand_more,
                  color: AppColors.textoClaroMedio),
              hint: Row(children: [
                const Icon(Icons.category_outlined,
                    size: 18, color: AppColors.textoClaroMedio),
                const SizedBox(width: 8),
                Text('Seleccionar...',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.textoClaroMedio
                            .withValues(alpha: 0.6))),
              ]),
              items: categorias
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.nombre,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        if (error) ...[
          const SizedBox(height: 4),
          Text('Selecciona una categoría',
              style: AppTypography.caption
                  .copyWith(color: AppColors.rojoAlerta)),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Foto picker
// ---------------------------------------------------------------------------

class _FotoPicker extends StatefulWidget {
  const _FotoPicker();

  @override
  State<_FotoPicker> createState() => _FotoPickerState();
}

class _FotoPickerState extends State<_FotoPicker> {
  bool _sel = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => setState(() => _sel = !_sel),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _sel
                ? AppColors.naranjaAccion.withValues(alpha: 0.15)
                : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _sel
                  ? AppColors.naranjaAccion.withValues(alpha: 0.6)
                  : AppColors.azulControl.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _sel ? Icons.camera_alt : Icons.camera_alt_outlined,
                color: _sel
                    ? AppColors.naranjaAccion
                    : AppColors.textoClaroMedio.withValues(alpha: 0.45),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                _sel ? 'Foto' : 'Añadir',
                style: AppTypography.caption.copyWith(
                  fontSize: 10,
                  color: _sel
                      ? AppColors.naranjaAccion
                      : AppColors.textoClaroMedio.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      );
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
  bool                           error    = false,
  bool                           numeric  = false,
  required VoidCallback          onChanged,
}) =>
    TextField(
      controller:      ctrl,
      onChanged:       (_) => onChanged(),
      style:           AppTypography.bodyMedium,
      keyboardType:    numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: AppTypography.caption.copyWith(
            color: AppColors.textoClaroMedio.withValues(alpha: 0.4)),
        filled:    true,
        fillColor: const Color(0xFF1E293B),
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
            color: error ? AppColors.rojoAlerta : AppColors.naranjaAccion,
          ),
        ),
      ),
    );

