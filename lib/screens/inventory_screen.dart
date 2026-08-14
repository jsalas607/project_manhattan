import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser user;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late DateTime _selectedDate;
  List<DailyInventoryRecord> _records = [];
  List<DateTime> _availableDates = [];
  bool _loading = true;
  bool _dayClosed = false;

  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Normaliza para búsqueda: minúsculas y sin acentos/ñ.
  static String _norm(String s) {
    s = s.toLowerCase();
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const to   = 'aaaaaeeeeiiiiooooouuuunc';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final idx = from.indexOf(ch);
      b.write(idx == -1 ? ch : to[idx]);
    }
    return b.toString();
  }

  List<DailyInventoryRecord> get _filtered {
    final q = _norm(_query.trim());
    if (q.isEmpty) return _records;
    return _records.where((r) => _norm(r.item.name).contains(q)).toList();
  }

  Future<void> _init() async {
    _availableDates = await MockInventoryApi.availableDates(widget.restaurant.id);
    _selectedDate = _availableDates.first; // hoy
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await MockInventoryApi.getByDate(widget.restaurant.id, _selectedDate);
    if (!mounted) return;
    setState(() {
      _records = data.records;
      _dayClosed = data.closed;
      _loading = false;
    });
  }

  void _showAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddItemSheet(
        onSave: ({required String name, required String unidad}) async {
          await MockInventoryApi.addItemToday(
              widget.restaurant.id, name: name, unidad: unidad);
          await _load();
        },
      ),
    );
  }

  Future<void> _closeDayInventory() async {
    final counted = _records.where((r) => r.entry.isCounted).length;
    final total   = _records.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Cerrar inventario del día', style: AppTypography.titleMedium),
        content: Text(
          counted < total
              ? '¿Cerrar inventario? Solo contaste $counted de $total productos. '
                'Los productos sin contar quedarán sin diferencia registrada.'
              : '¿Confirmas el cierre del inventario de hoy? '
                'Ya no podrás editarlo.',
          style: AppTypography.bodyMedium,
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
            child: Text('Cerrar inventario',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.naranjaAccion)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await MockInventoryApi.closeDayInventory(widget.restaurant.id, _selectedDate);
    if (mounted) setState(() => _dayClosed = true);
  }

  Future<void> _deleteItem(DailyInventoryRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Eliminar ingrediente', style: AppTypography.titleMedium),
        content: Text(
          'Se eliminará «${r.item.name}» del inventario, junto con su '
          'historial de conteos. Esto no afecta el menú.',
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
      await MockInventoryApi.deleteItem(widget.restaurant.id, r.item.id);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $e'),
          backgroundColor: AppColors.rojoAlerta,
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Text('Seleccionar día', style: AppTypography.titleMedium),
          const SizedBox(height: 8),
          ..._availableDates.map((date) {
            final isSelected = _dateKey(date) == _dateKey(_selectedDate);
            final isToday = _availableDates.isNotEmpty &&
                _dateKey(date) == _dateKey(_availableDates.first);
            return ListTile(
              leading: Icon(
                Icons.calendar_today,
                color: isSelected ? AppColors.naranjaAccion : AppColors.textoClaroMedio,
                size: 18,
              ),
              title: Text(
                isToday
                    ? 'Hoy — ${_formatDate(date)}'
                    : _formatDate(date),
                style: AppTypography.bodyLarge.copyWith(
                  color: isSelected ? AppColors.naranjaAccion : AppColors.textoClaroAlto,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppColors.naranjaAccion, size: 18)
                  : null,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedDate = date);
                _load();
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _availableDates.isNotEmpty &&
        _dateKey(_selectedDate) == _dateKey(_availableDates.first);
    final canDelete = widget.user.can('eliminar_inventario');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Administración de inventario', style: AppTypography.titleLarge),
      ),
      floatingActionButton: (isToday && !_dayClosed)
          ? FloatingActionButton.extended(
              onPressed: _showAddSheet,
              backgroundColor: AppColors.naranjaAccion,
              elevation: 2,
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              label: Text(
                'Añadir',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textoClaroAlto),
              ),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Usuario + sucursal
                RestaurantHeader(
                    restaurant: widget.restaurant, user: widget.user),
                const SizedBox(height: 12),

                // Banner: inventario cerrado
                if (_dayClosed) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.verdeExito.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.verdeExito.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock, color: AppColors.verdeExito, size: 16),
                        const SizedBox(width: 8),
                        Text('Inventario cerrado', style: AppTypography.labelLarge.copyWith(color: AppColors.verdeExito)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Botón cerrar inventario — solo si es hoy y no está cerrado
                if (isToday && !_dayClosed) ...[
                  // Progreso de conteo
                  Builder(builder: (_) {
                    final counted = _records.where((r) => r.entry.isCounted).length;
                    final total   = _records.length;
                    return OutlinedButton.icon(
                      onPressed: _closeDayInventory,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.naranjaAccion),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.lock_outline, color: AppColors.naranjaAccion, size: 18),
                      label: Text(
                        'Cerrar inventario del día  ($counted/$total contados)',
                        style: AppTypography.labelLarge.copyWith(color: AppColors.naranjaAccion),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                ],

                // Selector de día
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.naranjaAccion.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: AppColors.naranjaAccion, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isToday ? 'Hoy — ${_formatDate(_selectedDate)}' : _formatDate(_selectedDate),
                            style: AppTypography.labelLarge.copyWith(color: AppColors.naranjaAccion),
                          ),
                        ),
                        const Icon(Icons.expand_more, color: AppColors.naranjaAccion, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Buscador de ingredientes
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTypography.bodyMedium,
                  cursorColor: AppColors.naranjaAccion,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Buscar ingrediente…',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textoClaroMedio.withValues(alpha: 0.6)),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textoClaroMedio, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: AppColors.textoClaroMedio),
                            onPressed: () => setState(() {
                              _searchCtrl.clear();
                              _query = '';
                            }),
                          ),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppColors.azulControl.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.naranjaAccion, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),

          // Filas
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.naranjaAccion))
                : _records.isEmpty
                    ? Center(child: Text('Sin datos para este día', style: AppTypography.bodyMedium))
                    : _filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No hay ingredientes que coincidan.',
                              style: AppTypography.bodyMedium
                                  .copyWith(color: AppColors.textoClaroMedio),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _ItemRow(
                              record: _filtered[i],
                              canEdit: isToday && !_dayClosed,
                              onDelete: (isToday && !_dayClosed && canDelete)
                                  ? () => _deleteItem(_filtered[i])
                                  : null,
                              onUpdate: (itemId, invReal) async {
                                await MockInventoryApi.updateInvReal(
                                    widget.restaurant.id, _selectedDate, itemId, invReal);
                                await _load();
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _formatDate(DateTime d) =>
    DateFormat('dd MMM yyyy', 'es').format(d);

// ---------------------------------------------------------------------------
// Tarjeta de item
// ---------------------------------------------------------------------------

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.record,
    required this.canEdit,
    required this.onUpdate,
    this.onDelete,
  });

  final DailyInventoryRecord record;
  final bool canEdit;
  final Future<void> Function(String itemId, double invReal) onUpdate;
  final VoidCallback? onDelete;

  Color get _rowColor {
    if (!record.entry.isCounted) return const Color(0xFF1E293B);
    if (record.entry.hasDiff)    return AppColors.rojoAlerta.withValues(alpha: 0.12);
    return const Color(0xFF1E293B);
  }

  Color get _borderColor {
    if (!record.entry.isCounted) return AppColors.azulControl.withValues(alpha: 0.2);
    if (record.entry.hasDiff)    return AppColors.rojoAlerta.withValues(alpha: 0.4);
    return AppColors.verdeExito.withValues(alpha: 0.3);
  }

  @override
  Widget build(BuildContext context) {
    final isCounted = record.entry.isCounted;
    final diff      = record.entry.diff;
    final diffColor = diff < 0 ? AppColors.rojoAlerta : AppColors.verdeExito;
    final iconColor = isCounted
        ? (record.entry.hasDiff ? AppColors.rojoAlerta : AppColors.verdeExito)
        : AppColors.azulControl;

    final realColor = isCounted
        ? (record.entry.hasDiff ? AppColors.rojoAlerta : AppColors.verdeExito)
        : AppColors.textoClaroMedio;
    final difValueColor = isCounted
        ? (record.entry.hasDiff ? diffColor : AppColors.verdeExito)
        : AppColors.textoClaroMedio;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _rowColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado de la tarjeta: icono + nombre + botón
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.fastfood, size: 17, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(record.item.name,
                    style: AppTypography.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.rojoAlerta.withValues(alpha: 0.12),
                    ),
                    child: const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.rojoAlerta),
                  ),
                ),
              if (canEdit)
                GestureDetector(
                  onTap: () => _showEditSheet(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isCounted
                              ? AppColors.textoClaroMedio
                              : AppColors.naranjaAccion)
                          .withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      isCounted ? Icons.edit_outlined : Icons.add,
                      size: 17,
                      color: isCounted
                          ? AppColors.textoClaroMedio
                          : AppColors.naranjaAccion,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0x14FFFFFF)),
          const SizedBox(height: 10),

          // Datos: 4 columnas etiqueta / valor
          Row(
            children: [
              _StatCol(
                label: 'Esperado',
                value: '${record.entry.invApp.toInt()}',
              ),
              const _StatDivider(),
              _StatCol(
                label: 'Real',
                value: isCounted ? '${record.entry.invReal!.toInt()}' : '—',
                valueColor: realColor,
              ),
              const _StatDivider(),
              _StatCol(
                label: 'Unidad',
                value: record.item.unidad,
                small: true,
              ),
              const _StatDivider(),
              _StatCol(
                label: 'Dif.',
                value: isCounted
                    ? (diff >= 0 ? '+${diff.toInt()}' : '${diff.toInt()}')
                    : '—',
                valueColor: difValueColor,
                bold: isCounted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    final ctrl = TextEditingController(
      text: record.entry.invReal != null
          ? record.entry.invReal!.toInt().toString()
          : '',
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(record.item.name, style: AppTypography.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Inv. app: ${record.entry.invApp.toInt()} ${record.item.unidad}  (del día anterior)',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              style: AppTypography.bodyLarge,
              cursorColor: AppColors.naranjaAccion,
              decoration: InputDecoration(
                labelText: 'Conteo físico hoy (${record.item.unidad})',
                labelStyle: AppTypography.bodyMedium,
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.naranjaAccion, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(ctrl.text) ?? record.entry.invReal ?? 0;
                onUpdate(record.item.id, val);
                Navigator.pop(ctx);
              },
              child: const Text('Guardar conteo'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet: añadir item al inventario de hoy
// ---------------------------------------------------------------------------

class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet({required this.onSave});

  final Future<void> Function({
    required String name,
    required String unidad,
  }) onSave;

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _nameCtrl   = TextEditingController();
  final _unidadCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _unidadCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await widget.onSave(
      name:   _nameCtrl.text.trim(),
      unidad: _unidadCtrl.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Añadir ingrediente', style: AppTypography.titleLarge),
          const SizedBox(height: 4),
          Text('El conteo físico se registra desde la tabla', style: AppTypography.caption),
          const SizedBox(height: 16),
          _SheetField(ctrl: _nameCtrl,   label: 'Nombre del ingrediente'),
          const SizedBox(height: 10),
          _SheetField(ctrl: _unidadCtrl, label: 'Unidad (kg, gr, ml, und)'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textoClaroAlto),
                  )
                : const Text('Añadir'),
          ),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({required this.ctrl, required this.label, this.numeric = false});
  final TextEditingController ctrl;
  final String label;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
      style: AppTypography.bodyMedium,
      cursorColor: AppColors.naranjaAccion,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.caption,
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.naranjaAccion, width: 1.5),
        ),
      ),
    );
  }
}

// Columna etiqueta-encima / valor-debajo dentro de la tarjeta de item.
class _StatCol extends StatelessWidget {
  const _StatCol({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
    this.small = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool   bold;
  final bool   small;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.caption
                .copyWith(color: AppColors.textoClaroMedio, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: (small ? AppTypography.caption : AppTypography.bodyMedium)
                .copyWith(
              color: valueColor ?? AppColors.textoClaroAlto,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Separador vertical entre columnas de la tarjeta.
class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 0.5,
        height: 30,
        color: const Color(0x14FFFFFF),
      );
}
