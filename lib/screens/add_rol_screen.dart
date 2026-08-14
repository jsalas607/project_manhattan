import 'package:flutter/material.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../mock/gestion_empleado/mock_gestion_empleado_api.dart';
import '../widgets/restaurant_header.dart';

class AddRolScreen extends StatefulWidget {
  const AddRolScreen({
    super.key,
    required this.restaurant,
    required this.user,
    required this.onAdded,
  });

  final Restaurant  restaurant;
  final AppUser     user;
  final void Function(RolRestaurante) onAdded;

  @override
  State<AddRolScreen> createState() => _AddRolScreenState();
}

class _AddRolScreenState extends State<AddRolScreen> {
  final _nombreCtrl  = TextEditingController();
  final _filtroCtrl  = TextEditingController();
  final Set<String>  _permisos = {};
  bool               _saving   = false;
  bool               _intento  = false;
  String             _filtro   = '';

  @override
  void initState() {
    super.initState();
    _filtroCtrl.addListener(() => setState(() => _filtro = _filtroCtrl.text));
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _filtroCtrl.dispose();
    super.dispose();
  }

  List<String> get _permisosFiltrados {
    if (_filtro.trim().isEmpty) return kPermisos;
    final q = _filtro.toLowerCase();
    return kPermisos.where((p) {
      final label = kPermisosLabels[p] ?? p;
      return label.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() => _intento = true);
    if (_nombreCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final r = await MockGestionEmpleadoApi.addRol(
      widget.restaurant.id,
      nombre:   _nombreCtrl.text.trim(),
      permisos: _permisos.toList(),
    );
    if (!mounted) return;
    widget.onAdded(r);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final nombreVacio       = _intento && _nombreCtrl.text.trim().isEmpty;
    final permisosFiltrados = _permisosFiltrados;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Nuevo rol', style: AppTypography.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Usuario + sucursal
            RestaurantHeader(restaurant: widget.restaurant, user: widget.user),
            const SizedBox(height: 28),

            // ── Nombre del rol ────────────────────────────────────────────
            TextField(
              controller: _nombreCtrl,
              onChanged:  (_) => setState(() {}),
              style:      AppTypography.bodyMedium,
              decoration: InputDecoration(
                labelText: 'Nombre del rol',
                labelStyle: AppTypography.caption.copyWith(
                  color: nombreVacio
                      ? AppColors.rojoAlerta
                      : AppColors.textoClaroMedio,
                ),
                hintText:  'Ej: Mesero, Cocinero, Cajero...',
                hintStyle: AppTypography.caption.copyWith(
                    color: AppColors.textoClaroMedio.withValues(alpha: 0.4)),
                filled:    true,
                fillColor: const Color(0xFF1E293B),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: nombreVacio
                        ? AppColors.rojoAlerta
                        : AppColors.azulControl.withValues(alpha: 0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: nombreVacio
                        ? AppColors.rojoAlerta
                        : AppColors.naranjaAccion,
                  ),
                ),
              ),
            ),
            if (nombreVacio) ...[
              const SizedBox(height: 4),
              Text('Campo obligatorio',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.rojoAlerta)),
            ],
            const SizedBox(height: 24),

            // ── Lista de permisos ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lista de permisos', style: AppTypography.labelLarge),
                if (_permisos.isNotEmpty)
                  Text(
                    '${_permisos.length} seleccionado${_permisos.length == 1 ? "" : "s"}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.naranjaAccion),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Buscador de permisos
            TextField(
              controller: _filtroCtrl,
              style:      AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Buscar permiso...',
                hintStyle: AppTypography.caption.copyWith(
                    color: AppColors.textoClaroMedio.withValues(alpha: 0.4)),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textoClaroMedio, size: 20),
                filled:    true,
                fillColor: const Color(0xFF1E293B),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: AppColors.azulControl.withValues(alpha: 0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.naranjaAccion),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Chips de permisos
            if (permisosFiltrados.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No hay permisos que coincidan.',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textoClaroMedio),
                ),
              )
            else
              Wrap(
                spacing:    10,
                runSpacing: 10,
                children: permisosFiltrados.map((p) {
                  final label      = kPermisosLabels[p] ?? p;
                  final isSelected = _permisos.contains(p);
                  return _PermisoChip(
                    label:      label,
                    selected:   isSelected,
                    onTap: () => setState(() {
                      if (isSelected) _permisos.remove(p);
                      else            _permisos.add(p);
                    }),
                  );
                }).toList(),
              ),

            const SizedBox(height: 32),

            // ── Botón GUARDAR ─────────────────────────────────────────────
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
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      'GUARDAR',
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.textoClaroAlto),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip de permiso (toggle)
// ---------------------------------------------------------------------------

class _PermisoChip extends StatelessWidget {
  const _PermisoChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

