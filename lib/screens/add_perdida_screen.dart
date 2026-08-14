import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';

class AddPerdidaScreen extends StatefulWidget {
  const AddPerdidaScreen({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser user;

  @override
  State<AddPerdidaScreen> createState() => _AddPerdidaScreenState();
}

// ---------------------------------------------------------------------------
// Modelo interno de fila de producto dañado
// ---------------------------------------------------------------------------

class _PerdidaRow {
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

class _AddPerdidaScreenState extends State<AddPerdidaScreen> {
  final _tituloCtrl      = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final List<_PerdidaRow> _filas = [];
  List<InventoryItem> _catalog = [];
  bool _saving         = false;
  bool _intentoGuardar = false; // muestra errores al tocar "Registrar"

  @override
  void initState() {
    super.initState();
    _filas.add(_PerdidaRow()); // siempre arranca con una fila
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final catalog = await MockInventoryApi.getCatalog(widget.restaurant.id);
    if (!mounted) return;
    setState(() => _catalog = catalog);
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    for (final f in _filas) {
      f.dispose();
    }
    super.dispose();
  }

  void _addFila() => setState(() => _filas.add(_PerdidaRow()));

  void _removeFila(int i) {
    setState(() {
      _filas[i].dispose();
      _filas.removeAt(i);
    });
  }

  Future<void> _save() async {
    setState(() => _intentoGuardar = true);

    final titulo      = _tituloCtrl.text.trim();
    final descripcion = _descripcionCtrl.text.trim();

    if (titulo.isEmpty) {
      _snack('Escribe el título de la pérdida');
      return;
    }
    if (descripcion.isEmpty) {
      _snack('Describe qué pasó en la descripción del daño');
      return;
    }

    // Solo filas con producto seleccionado Y cantidad válida
    final filasValidas = _filas
        .where((f) =>
            f.selectedItem != null &&
            (double.tryParse(f.cantidadCtrl.text) ?? 0) > 0)
        .toList();

    if (filasValidas.isEmpty) {
      _snack('Selecciona al menos un producto con cantidad');
      return;
    }

    setState(() => _saving = true);

    final productos = filasValidas
        .map((f) => PerdidaProducto(
              name:     f.name,
              cantidad: double.tryParse(f.cantidadCtrl.text) ?? 0,
              unidad:   f.unidadCtrl.text.trim().isNotEmpty
                  ? f.unidadCtrl.text.trim()
                  : null,
              itemId:   f.selectedItem?.id,
            ))
        .toList();

    // 1. Registrar la pérdida (categoría por defecto, ya no se elige en la UI)
    await MockCarteraApi.addPerdida(
      widget.restaurant.id,
      titulo:      titulo,
      descripcion: _descripcionCtrl.text.trim(),
      categoria:   'otro',
      productos:   productos,
    );

    // 2. Descontar del inventario los productos del catálogo
    final today = DateTime.now();
    for (final f in filasValidas) {
      final cantidad = double.tryParse(f.cantidadCtrl.text) ?? 0;
      if (f.selectedItem != null && cantidad > 0) {
        await MockInventoryApi.registrarMerma(
            widget.restaurant.id, today, f.selectedItem!.id, cantidad);
      }
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
        title: Text('Añadir pérdida', style: AppTypography.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Usuario + sucursal
            RestaurantHeader(restaurant: widget.restaurant, user: widget.user),
            const SizedBox(height: 20),

            // Título de la pérdida
            Text('Título de la pérdida', style: AppTypography.labelLarge),
            const SizedBox(height: 6),
            _DarkField(
                ctrl: _tituloCtrl, hint: 'Ej: Pollo vencido, Platos rotos…'),
            const SizedBox(height: 16),

            // Descripción del daño *
            _RequiredLabel('Descripción del daño'),
            const SizedBox(height: 6),
            Builder(builder: (ctx) {
              final vacia =
                  _intentoGuardar && _descripcionCtrl.text.trim().isEmpty;
              final borderSide = vacia
                  ? const BorderSide(
                      color: AppColors.rojoAlerta, width: 1.5)
                  : BorderSide.none;
              return TextField(
                controller: _descripcionCtrl,
                maxLines: 3,
                style: AppTypography.bodyLarge,
                cursorColor: AppColors.naranjaAccion,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Describe qué pasó…',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                      color:
                          AppColors.textoClaroMedio.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: borderSide),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: vacia
                        ? const BorderSide(
                            color: AppColors.rojoAlerta, width: 1.5)
                        : const BorderSide(
                            color: AppColors.naranjaAccion, width: 1.5),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),

            // Divisor productos dañados
            Row(
              children: [
                Expanded(
                    child: Divider(
                        color: AppColors.azulControl.withValues(alpha: 0.3))),
                const SizedBox(width: 10),
                Row(
                  children: [
                    Text('Productos dañados', style: AppTypography.caption),
                    const SizedBox(width: 4),
                    Text('*',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.rojoAlerta)),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Divider(
                        color: AppColors.azulControl.withValues(alpha: 0.3))),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Mínimo un producto — se descontará del inventario',
              style: AppTypography.caption
                  .copyWith(color: AppColors.rojoAlerta.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Filas de producto
            ..._filas.asMap().entries.map(
                  (e) => _PerdidaRowWidget(
                    key: ValueKey(e.key),
                    row: e.value,
                    catalog: _catalog,
                    onRemove: () => _removeFila(e.key),
                    onChanged: () => setState(() {}),
                    intentoGuardar: _intentoGuardar,
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
              label: const Text('Añadir otro producto dañado'),
            ),
            const SizedBox(height: 32),

            // Botón registrar
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rojoAlerta,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.textoClaroAlto),
                    )
                  : const Text('Registrar pérdida'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget de fila de producto dañado
// ---------------------------------------------------------------------------

class _PerdidaRowWidget extends StatefulWidget {
  const _PerdidaRowWidget({
    super.key,
    required this.row,
    required this.catalog,
    required this.onRemove,
    required this.onChanged,
    this.intentoGuardar = false,
  });

  final _PerdidaRow row;
  final List<InventoryItem> catalog;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final bool intentoGuardar;

  @override
  State<_PerdidaRowWidget> createState() => _PerdidaRowWidgetState();
}

class _PerdidaRowWidgetState extends State<_PerdidaRowWidget> {
  Future<void> _abrirSelector() async {
    final item = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ProductPickerSheet(catalog: widget.catalog),
    );
    if (item != null) {
      setState(() {
        widget.row.selectedItem = item;
        widget.row.name = item.name;
        widget.row.unidadCtrl.text = item.unidad;
      });
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sinSeleccion =
        widget.intentoGuardar && widget.row.selectedItem == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.azulControl.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Producto', style: AppTypography.labelLarge),
              GestureDetector(
                onTap: widget.onRemove,
                child: const Icon(Icons.close,
                    size: 18, color: AppColors.rojoAlerta),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Campo tappable — abre el buscador
          GestureDetector(
            onTap: _abrirSelector,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: sinSeleccion
                      ? AppColors.rojoAlerta
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.row.name.isEmpty
                          ? 'Buscar en inventario…'
                          : widget.row.name,
                      style: widget.row.name.isEmpty
                          ? AppTypography.bodyMedium.copyWith(
                              color: AppColors.textoClaroMedio
                                  .withValues(alpha: 0.4))
                          : AppTypography.bodyLarge,
                    ),
                  ),
                  Icon(
                    widget.row.selectedItem != null
                        ? Icons.check_circle
                        : Icons.search,
                    size: 18,
                    color: widget.row.selectedItem != null
                        ? AppColors.verdeExito
                        : AppColors.textoClaroMedio,
                  ),
                ],
              ),
            ),
          ),
          if (sinSeleccion)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'Selecciona un producto del inventario',
                style:
                    AppTypography.caption.copyWith(color: AppColors.rojoAlerta),
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
// Bottom sheet buscador de producto
// ---------------------------------------------------------------------------

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.catalog});
  final List<InventoryItem> catalog;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.catalog
        : widget.catalog
            .where((item) =>
                item.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textoClaroMedio.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Seleccionar producto',
                style: AppTypography.titleLarge),
          ),
          // Buscador
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: AppTypography.bodyLarge,
              cursorColor: AppColors.naranjaAccion,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Buscar producto…',
                hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textoClaroMedio.withValues(alpha: 0.4)),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textoClaroMedio, size: 20),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.naranjaAccion, width: 1.5),
                ),
              ),
            ),
          ),
          // Lista
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'Sin resultados',
                      style: AppTypography.bodyMedium.copyWith(
                          color:
                              AppColors.textoClaroMedio.withValues(alpha: 0.5)),
                    ),
                  )
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, i) => Divider(
                        color: AppColors.azulControl.withValues(alpha: 0.3),
                        height: 1),
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 4),
                        title: Text(item.name, style: AppTypography.bodyLarge),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppColors.azulControl.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(item.unidad,
                              style: AppTypography.caption),
                        ),
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers / widgets internos
// ---------------------------------------------------------------------------

class _DarkField extends StatelessWidget {
  const _DarkField({required this.ctrl, required this.hint});
  final TextEditingController ctrl;
  final String hint;

  @override
  Widget build(BuildContext context) =>
      _buildRawField(controller: ctrl, hint: hint);
}

Widget _buildRawField({
  required TextEditingController controller,
  FocusNode? focusNode,
  required String hint,
  bool numeric = false,
  bool enabled = true,
  Color? highlightColor, // borde de error/aviso
}) {
  final enabledSide = highlightColor != null
      ? BorderSide(color: highlightColor, width: 1.5)
      : BorderSide.none;

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
      fillColor:
          enabled ? const Color(0xFF0F172A) : const Color(0xFF0A111E),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: enabledSide),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: highlightColor != null
            ? BorderSide(color: highlightColor, width: 1.5)
            : const BorderSide(color: AppColors.naranjaAccion, width: 1.5),
      ),
    ),
  );
}

// Etiqueta con asterisco rojo de campo obligatorio
class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(text, style: AppTypography.labelLarge),
          const SizedBox(width: 4),
          Text('*',
              style: AppTypography.labelLarge
                  .copyWith(color: AppColors.rojoAlerta)),
        ],
      );
}

