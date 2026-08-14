import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/app_text_field.dart';
import '../widgets/restaurant_header.dart';
import 'add_rol_screen.dart';

class EditEmpleadoScreen extends StatefulWidget {
  const EditEmpleadoScreen({
    super.key,
    required this.restaurant,
    required this.user,
    required this.empleado,
    required this.roles,
    required this.onEdited,
  });

  final Restaurant              restaurant;
  final AppUser                 user;
  final Empleado                empleado;
  final List<RolRestaurante>    roles;
  final void Function(Empleado) onEdited;

  @override
  State<EditEmpleadoScreen> createState() => _EditEmpleadoScreenState();
}

class _EditEmpleadoScreenState extends State<EditEmpleadoScreen> {
  late final TextEditingController _nombreCtrl;
  late List<RolRestaurante> _roles;
  late String               _selectedRolId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl    = TextEditingController(text: widget.empleado.nombre);
    _roles         = List.of(widget.roles);
    _selectedRolId = widget.empleado.rolId;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  String get _rolActualNombre {
    try {
      return _roles.firstWhere((r) => r.id == widget.empleado.rolId).nombre;
    } catch (_) {
      return 'Sin rol';
    }
  }

  // ── Ir a crear nuevo rol ──────────────────────────────────────────────────

  Future<void> _goToNuevoRol() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRolScreen(
          restaurant: widget.restaurant,
          user:       widget.user,
          onAdded: (nuevoRol) => setState(() {
            _roles         = [..._roles, nuevoRol];
            _selectedRolId = nuevoRol.id;
          }),
        ),
      ),
    );
  }

  // ── Guardar ───────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (_nombreCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final updated = await MockGestionEmpleadoApi.editEmpleado(
      widget.restaurant.id,
      empleadoId: widget.empleado.id,
      nombre:     _nombreCtrl.text.trim(),
      rolId:      _selectedRolId,
    );
    if (!mounted) return;
    widget.onEdited(updated);
    Navigator.pop(context);
  }

  // ── Zona admin: cambiar contraseña ────────────────────────────────────────

  void _cambiarPassword() {
    final passCtrl = TextEditingController();
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
            Text('Cambiar contraseña', style: AppTypography.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Nueva contraseña para «${widget.empleado.nombre}».',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textoClaroMedio),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Nueva contraseña',
              controller: passCtrl,
              isPassword: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final pass = passCtrl.text;
                if (pass.isEmpty) return;
                try {
                  await MockGestionEmpleadoApi.cambiarPasswordUsuario(
                      widget.empleado.userId, pass);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.verdeExito,
                      content: Text('Contraseña actualizada',
                          style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textoOscuroAlto)),
                    ),
                  );
                } on ApiException catch (e) {
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.rojoAlerta,
                      content: Text('No se pudo cambiar: ${e.message}'),
                    ),
                  );
                }
              },
              child: const Text('Guardar contraseña'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Zona admin: eliminar usuario del sistema ──────────────────────────────

  Future<void> _eliminarUsuario() async {
    final n = widget.empleado.nombre;
    final ok1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Eliminar usuario', style: AppTypography.titleMedium),
        content: Text(
          '¿Eliminar la cuenta de «$n» del sistema?',
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
    if (ok1 != true || !mounted) return;

    final ok2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('¿Estás seguro?', style: AppTypography.titleMedium),
        content: Text(
          'Se borrará su cuenta y saldrá de TODOS los restaurantes. '
          'Esta acción no se puede deshacer.',
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
            child: Text('Sí, eliminar',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.rojoAlerta)),
          ),
        ],
      ),
    );
    if (ok2 != true || !mounted) return;

    try {
      await MockGestionEmpleadoApi.eliminarUsuario(widget.empleado.userId);
      if (!mounted) return;
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.rojoAlerta,
          content: Text('No se pudo eliminar: ${e.message}'),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
        title: Text('Editar empleado', style: AppTypography.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Usuario + sucursal
            RestaurantHeader(restaurant: widget.restaurant, user: widget.user),
            const SizedBox(height: 28),

            // ── Nombre + Rol actual (lado a lado) ─────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre (editable)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nombre', style: AppTypography.caption
                          .copyWith(color: AppColors.textoClaroMedio)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nombreCtrl,
                        style:      AppTypography.bodyMedium,
                        decoration: InputDecoration(
                          filled:    true,
                          fillColor: const Color(0xFF1E293B),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 13),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: AppColors.azulControl
                                    .withValues(alpha: 0.4)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.naranjaAccion),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Rol actual (solo lectura)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rol actual', style: AppTypography.caption
                          .copyWith(color: AppColors.textoClaroMedio)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.azulControl
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          _rolActualNombre,
                          style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.azulControl),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Selector de rol ───────────────────────────────────────────
            Text('Selector de roles', style: AppTypography.labelLarge),
            const SizedBox(height: 6),
            Text(
              'Elige el nuevo rol para este empleado.',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textoClaroMedio),
            ),
            const SizedBox(height: 12),

            if (_roles.isEmpty)
              _WarningBox(
                  text: 'No hay roles creados. Presiona "Nuevo rol" para crear uno.')
            else
              Wrap(
                spacing:    10,
                runSpacing: 10,
                children: [
                  ..._roles.map((r) {
                    final isSelected = r.id == _selectedRolId;
                    return _RolChip(
                      label:      r.nombre,
                      selected:   isSelected,
                      onTap: () => setState(() => _selectedRolId = r.id),
                    );
                  }),

                  // Chip especial "Nuevo rol"
                  _NuevoRolChip(onTap: _goToNuevoRol),
                ],
              ),

            const SizedBox(height: 36),

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

            // ── Zona de administrador ─────────────────────────────────────
            if (widget.user.isAdmin) ...[
              const SizedBox(height: 32),
              const Divider(height: 1, color: Color(0xFF334155)),
              const SizedBox(height: 16),
              Text('Zona de administrador',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.textoClaroMedio,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _cambiarPassword,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.azulControl,
                  side: BorderSide(
                      color: AppColors.azulControl.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.key_outlined, size: 18),
                label: const Text('Cambiar contraseña'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _eliminarUsuario,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rojoAlerta,
                  side: BorderSide(
                      color: AppColors.rojoAlerta.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.person_remove_outlined, size: 18),
                label: const Text('Eliminar usuario del sistema'),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip de rol (toggle)
// ---------------------------------------------------------------------------

class _RolChip extends StatelessWidget {
  const _RolChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.azulControl : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.azulControl
                : AppColors.azulControl.withValues(alpha: 0.35),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
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

// ---------------------------------------------------------------------------
// Chip especial "Nuevo rol"
// ---------------------------------------------------------------------------

class _NuevoRolChip extends StatelessWidget {
  const _NuevoRolChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.naranjaAccion.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.naranjaAccion.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: AppColors.naranjaAccion, size: 16),
            const SizedBox(width: 6),
            Text(
              'Nuevo rol',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.naranjaAccion),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.naranjaAccion.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.naranjaAccion.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined,
                color: AppColors.naranjaAccion, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.naranjaAccion)),
            ),
          ],
        ),
      );
}
