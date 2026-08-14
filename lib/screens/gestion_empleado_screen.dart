import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../mock/gestion_empleado/mock_gestion_empleado_api.dart';
import '../widgets/restaurant_header.dart';
import 'add_empleado_screen.dart';
import 'add_rol_screen.dart';
import 'edit_empleado_screen.dart';

class GestionEmpleadoScreen extends StatefulWidget {
  const GestionEmpleadoScreen({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser    user;

  @override
  State<GestionEmpleadoScreen> createState() => _GestionEmpleadoScreenState();
}

class _GestionEmpleadoScreenState extends State<GestionEmpleadoScreen> {
  List<Empleado>       _empleados = [];
  List<RolRestaurante> _roles     = [];
  bool                 _loading   = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final e = await MockGestionEmpleadoApi.getEmpleados(widget.restaurant.id);
    final r = await MockGestionEmpleadoApi.getRoles(widget.restaurant.id);
    if (!mounted) return;
    setState(() {
      _empleados = e;
      _roles     = r;
      _loading   = false;
    });
  }

  // ── Empleados ──────────────────────────────────────────────────────────────

  Future<void> _showAddEmpleadoSheet() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEmpleadoScreen(
          restaurant: widget.restaurant,
          user:       widget.user,
          roles:      _roles,
          onAdded: (e) => setState(() => _empleados = [..._empleados, e]),
        ),
      ),
    );
  }

  Future<void> _showEditEmpleadoSheet(Empleado e) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditEmpleadoScreen(
          restaurant: widget.restaurant,
          user:       widget.user,
          empleado:   e,
          roles:      _roles,
          onEdited: (updated) => setState(() {
            final idx = _empleados.indexWhere((x) => x.id == e.id);
            if (idx != -1) _empleados[idx] = updated;
          }),
        ),
      ),
    );
    // Recarga todo al volver: roles nuevos y/o empleado eliminado del sistema
    if (!mounted) return;
    await _load();
  }

  /// Al tocar la papelera: el dueño elige entre quitar del restaurante
  /// (borra la membresía) o eliminar la cuenta completa de la base de datos.
  /// Los demás (gerentes) solo pueden quitar del restaurante → acción directa.
  Future<void> _deleteEmpleado(Empleado e) async {
    if (!widget.user.isAdmin) {
      await _quitarDelRestaurante(e);
      return;
    }
    final accion = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text('¿Qué deseas hacer con ${e.nombre}?',
                  style: AppTypography.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined,
                  color: AppColors.azulControl),
              title: Text('Quitar del restaurante',
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textoClaroAlto)),
              subtitle: Text('Sale de este restaurante; la cuenta se conserva.',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textoClaroMedio)),
              onTap: () => Navigator.pop(context, 'quitar'),
            ),
            // Borrar la cuenta de la BD es exclusivo del dueño (el backend
            // responde 403 a los demás), así que solo a él se le ofrece.
            if (widget.user.isAdmin)
              ListTile(
                leading: const Icon(Icons.delete_forever,
                    color: AppColors.rojoAlerta),
                title: Text('Eliminar cuenta del sistema',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.rojoAlerta)),
                subtitle: Text(
                    'Borra la cuenta de la base de datos por completo.',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textoClaroMedio)),
                onTap: () => Navigator.pop(context, 'eliminar'),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (accion == null || !mounted) return;
    if (accion == 'quitar') {
      await _quitarDelRestaurante(e);
    } else {
      await _eliminarCuenta(e);
    }
  }

  Future<void> _quitarDelRestaurante(Empleado e) async {
    final ok = await _doubleConfirm(
      context,
      title:    'Quitar del restaurante',
      subtitle: '¿Quitar a ${e.nombre} de este restaurante?',
      detail:   '${e.nombre} perderá acceso a este restaurante. Su cuenta se conserva.',
    );
    if (!ok || !mounted) return;
    try {
      await MockGestionEmpleadoApi.removeEmpleado(widget.restaurant.id, e.id);
      if (!mounted) return;
      setState(() => _empleados.removeWhere((x) => x.id == e.id));
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.message)),
      );
    }
  }

  Future<void> _eliminarCuenta(Empleado e) async {
    final ok = await _doubleConfirm(
      context,
      title:    'Eliminar cuenta del sistema',
      subtitle: '¿Eliminar la cuenta de ${e.nombre} por completo?',
      detail:   'Se borra la cuenta de la base de datos y sale de TODOS los '
          'restaurantes. Esta acción no se puede deshacer.',
    );
    if (!ok || !mounted) return;
    try {
      await MockGestionEmpleadoApi.eliminarUsuario(e.userId);
      if (!mounted) return;
      setState(() => _empleados.removeWhere((x) => x.id == e.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cuenta de ${e.nombre} eliminada')),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.message)),
      );
    }
  }

  // ── Roles ──────────────────────────────────────────────────────────────────

  Future<void> _showAddRolSheet() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRolScreen(
          restaurant: widget.restaurant,
          user:       widget.user,
          onAdded: (r) => setState(() => _roles = [..._roles, r]),
        ),
      ),
    );
  }

  Future<void> _deleteRol(RolRestaurante r) async {
    final ok = await _doubleConfirm(
      context,
      title:    'Eliminar rol',
      subtitle: '¿Eliminar el rol "${r.nombre}"?',
      detail:   'Los empleados con este rol quedarán sin rol asignado.',
    );
    if (!ok || !mounted) return;
    await MockGestionEmpleadoApi.removeRol(widget.restaurant.id, r.id);
    if (!mounted) return;
    setState(() => _roles.removeWhere((x) => x.id == r.id));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
        title: Text('Gestionar empleado', style: AppTypography.titleLarge),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.naranjaAccion))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Usuario + sucursal
                  RestaurantHeader(
                      restaurant: widget.restaurant, user: widget.user),
                  const SizedBox(height: 28),

                  // ── Sección: Empleados ──────────────────────────────────
                  Text('Empleados', style: AppTypography.titleMedium),
                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.88,
                    children: [
                      ..._empleados.map((e) => _EmpleadoCard(
                            empleado:  e,
                            roles:     _roles,
                            onEdit:    () => _showEditEmpleadoSheet(e),
                            onDelete:  () => _deleteEmpleado(e),
                          )),
                      _AgregarCard(
                        label: 'Añadir\nempleado',
                        onTap: _showAddEmpleadoSheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Sección: Roles ──────────────────────────────────────
                  Text('Roles', style: AppTypography.titleMedium),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.azulControl.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_roles.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Sin roles creados. Añade el primero.',
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.textoClaroMedio),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ..._roles.asMap().entries.map((entry) => _RolItem(
                                rol:    entry.value,
                                isLast: entry.key == _roles.length - 1,
                                onDelete: () => _deleteRol(entry.value),
                              )),

                        // Botón añadir rol
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _showAddRolSheet,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.naranjaAccion,
                                  foregroundColor: AppColors.textoClaroAlto,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text('Añadir rol nuevo',
                                    style: AppTypography.caption.copyWith(
                                        color: AppColors.textoClaroAlto)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Doble confirmación de eliminación
// ---------------------------------------------------------------------------

Future<bool> _doubleConfirm(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String detail,
}) async {
  final step1 = await showDialog<bool>(
    context: context,
    builder: (_) => _ConfirmDialog(
      title:        title,
      body:         subtitle,
      confirmLabel: 'Eliminar',
    ),
  );
  if (step1 != true || !context.mounted) return false;

  final step2 = await showDialog<bool>(
    context: context,
    builder: (_) => _ConfirmDialog(
      title:        '¿Estás completamente seguro?',
      body:         detail,
      confirmLabel: 'Sí, eliminar',
    ),
  );
  return step2 == true;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
  });
  final String title, body, confirmLabel;

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: AppTypography.titleMedium),
        content: Text(body, style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textoClaroMedio)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.rojoAlerta)),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Tarjeta de empleado
// ---------------------------------------------------------------------------

class _EmpleadoCard extends StatelessWidget {
  const _EmpleadoCard({
    required this.empleado,
    required this.roles,
    required this.onEdit,
    required this.onDelete,
  });

  final Empleado             empleado;
  final List<RolRestaurante> roles;
  final VoidCallback         onEdit;
  final VoidCallback         onDelete;

  String get _rolNombre {
    try {
      return roles.firstWhere((r) => r.id == empleado.rolId).nombre;
    } catch (_) {
      return 'Sin rol';
    }
  }

  String get _initials {
    final parts = empleado.nombre.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return empleado.nombre.isNotEmpty
        ? empleado.nombre[0].toUpperCase()
        : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.azulControl.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              // Avatar con iniciales
              CircleAvatar(
                radius: 26,
                backgroundColor:
                    AppColors.azulControl.withValues(alpha: 0.35),
                child: Text(
                  _initials,
                  style: AppTypography.titleMedium
                      .copyWith(color: AppColors.textoClaroAlto),
                ),
              ),
              const SizedBox(height: 8),
              // Nombre
              Text(
                empleado.nombre,
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Chip de rol
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.azulControl.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _rolNombre,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.azulControl),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Acciones
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _IconBtn(
                  icon: Icons.edit_outlined,
                  color: AppColors.textoClaroMedio,
                  onTap: onEdit),
              const SizedBox(width: 2),
              _IconBtn(
                  icon: Icons.delete_outline,
                  color: AppColors.rojoAlerta,
                  onTap: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta "Añadir"
// ---------------------------------------------------------------------------

class _AgregarCard extends StatelessWidget {
  const _AgregarCard({required this.label, required this.onTap});
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: AppColors.naranjaAccion.withValues(alpha: 0.1),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.naranjaAccion.withValues(alpha: 0.35)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.naranjaAccion.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.person_add_outlined,
                      color: AppColors.naranjaAccion, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.naranjaAccion),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Fila de rol
// ---------------------------------------------------------------------------

class _RolItem extends StatelessWidget {
  const _RolItem({
    required this.rol,
    required this.isLast,
    required this.onDelete,
  });
  final RolRestaurante rol;
  final bool           isLast;
  final VoidCallback   onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                    color: AppColors.azulControl.withValues(alpha: 0.2))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rol.nombre, style: AppTypography.labelLarge),
                const SizedBox(height: 8),
                if (rol.permisos.isEmpty)
                  Text('Sin permisos asignados',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textoClaroMedio))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: rol.permisos.map((p) {
                      final label = kPermisosLabels[p] ?? p;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.azulControl.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color:
                                  AppColors.azulControl.withValues(alpha: 0.3)),
                        ),
                        child: Text(label,
                            style: AppTypography.caption
                                .copyWith(fontSize: 11)),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                color: AppColors.rojoAlerta, size: 20),
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}



// ---------------------------------------------------------------------------
// Widgets genéricos de formulario
// ---------------------------------------------------------------------------

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.error    = false,
    this.onChanged,
  });
  final TextEditingController      controller;
  final String                     label;
  final String?                    hint;
  final bool                       error;
  final void Function(String)?     onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged:  onChanged,
        style:      AppTypography.bodyMedium,
        decoration: InputDecoration(
          labelText: label,
          hintText:  hint,
          labelStyle: AppTypography.caption.copyWith(
            color: error ? AppColors.rojoAlerta : AppColors.textoClaroMedio,
          ),
          hintStyle: AppTypography.caption.copyWith(
            color: AppColors.textoClaroMedio.withValues(alpha: 0.4),
          ),
          filled:    true,
          fillColor: const Color(0xFF0F172A),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: error
                  ? AppColors.rojoAlerta
                  : AppColors.azulControl.withValues(alpha: 0.4),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color:
                  error ? AppColors.rojoAlerta : AppColors.naranjaAccion,
            ),
          ),
        ),
      );
}

class _SheetDropdown<T> extends StatelessWidget {
  const _SheetDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.label,
  });
  final T?                       value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)        onChanged;
  final String                   label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.azulControl.withValues(alpha: 0.4)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value:          value,
            items:          items,
            onChanged:      onChanged,
            isExpanded:     true,
            dropdownColor:  const Color(0xFF1E293B),
            style:          AppTypography.bodyMedium,
            iconEnabledColor: AppColors.textoClaroMedio,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Caja de resultado de búsqueda
// ---------------------------------------------------------------------------

class _ResultBox extends StatelessWidget {
  const _ResultBox(
      {required this.color, required this.icon, required this.text});
  final Color    color;
  final IconData icon;
  final String   text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text, style: AppTypography.bodyMedium)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Botón icono pequeño
// ---------------------------------------------------------------------------

class _IconBtn extends StatelessWidget {
  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: 18),
        ),
      );
}

