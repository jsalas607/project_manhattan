import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/app_text_field.dart';

/// Administrador de dueños: los clientes que pagan por usar el software.
/// Solo el superadmin llega aquí (el backend responde 403 al resto).
class DuenosScreen extends StatefulWidget {
  const DuenosScreen({super.key});

  @override
  State<DuenosScreen> createState() => _DuenosScreenState();
}

class _DuenosScreenState extends State<DuenosScreen> {
  List<Dueno> _duenos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await MockAdminApi.getDuenos();
      if (!mounted) return;
      setState(() {
        _duenos = d;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo conectar con el servidor';
        _loading = false;
      });
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  // ── Crear dueño ────────────────────────────────────────────────────────────
  Future<void> _crearDueno() async {
    final nombreCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nuevo dueño', style: AppTypography.titleMedium),
              const SizedBox(height: 4),
              Text('Cliente que empieza a pagar por el software',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textoClaroMedio)),
              const SizedBox(height: 18),
              AppTextField(label: 'Nombre', controller: nombreCtrl),
              const SizedBox(height: 12),
              AppTextField(label: 'Usuario', controller: userCtrl),
              const SizedBox(height: 12),
              AppTextField(
                  label: 'Contraseña', controller: passCtrl, isPassword: true),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final nombre = nombreCtrl.text.trim();
                        final username = userCtrl.text.trim();
                        final pass = passCtrl.text;
                        if (username.isEmpty || pass.isEmpty) {
                          _snack('Usuario y contraseña son obligatorios');
                          return;
                        }
                        setSheet(() => saving = true);
                        try {
                          await MockAdminApi.crearDueno(
                            username: username,
                            password: pass,
                            nombre: nombre.isEmpty ? username : nombre,
                          );
                          if (!sheetCtx.mounted) return;
                          Navigator.pop(sheetCtx);
                          _snack('Dueño «$username» creado');
                          await _load();
                        } on ApiException catch (e) {
                          setSheet(() => saving = false);
                          _snack(e.message);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.textoClaroAlto),
                      )
                    : const Text('Crear dueño'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cambiar contraseña ─────────────────────────────────────────────────────
  Future<void> _cambiarPassword(Dueno d) async {
    final passCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Contraseña de ${d.nombre}',
                style: AppTypography.titleMedium),
            const SizedBox(height: 18),
            AppTextField(
                label: 'Nueva contraseña',
                controller: passCtrl,
                isPassword: true),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final pass = passCtrl.text;
                if (pass.trim().isEmpty) {
                  _snack('La contraseña no puede estar vacía');
                  return;
                }
                try {
                  await MockAdminApi.cambiarPassword(d.id, pass);
                  if (!sheetCtx.mounted) return;
                  Navigator.pop(sheetCtx);
                  _snack('Contraseña de ${d.nombre} actualizada');
                } on ApiException catch (e) {
                  if (!sheetCtx.mounted) return;
                  Navigator.pop(sheetCtx);
                  _snack(e.message);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Activar / desactivar ───────────────────────────────────────────────────
  Future<void> _toggleActivo(Dueno d) async {
    if (d.isActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('¿Desactivar a ${d.nombre}?',
              style: AppTypography.titleMedium),
          content: Text(
            'No podrá iniciar sesión y sus empleados tampoco tendrán acceso a '
            'sus restaurantes. No se borra nada: puedes reactivarlo cuando quieras.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar',
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textoClaroMedio)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Desactivar',
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.rojoAlerta)),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    try {
      final actualizado = await MockAdminApi.setActivo(d.id, !d.isActive);
      if (!mounted) return;
      setState(() {
        final i = _duenos.indexWhere((x) => x.id == d.id);
        if (i != -1) _duenos[i] = actualizado;
      });
      _snack(actualizado.isActive
          ? '${d.nombre} reactivado'
          : '${d.nombre} desactivado');
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    }
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
        title: Text('Dueños', style: AppTypography.titleLarge),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearDueno,
        backgroundColor: AppColors.naranjaAccion,
        icon: const Icon(Icons.person_add_alt, color: Colors.white, size: 20),
        label: Text('Añadir dueño',
            style:
                AppTypography.caption.copyWith(color: AppColors.textoClaroAlto)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.naranjaAccion))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: AppTypography.bodyMedium,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton(
                            onPressed: _load, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    children: [
                      Text(
                        _duenos.isEmpty
                            ? 'Aún no hay dueños registrados.'
                            : '${_duenos.length} '
                                '${_duenos.length == 1 ? "dueño" : "dueños"}',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textoClaroMedio),
                      ),
                      const SizedBox(height: 12),
                      ..._duenos.map((d) => _DuenoCard(
                            dueno: d,
                            onPassword: () => _cambiarPassword(d),
                            onToggle: () => _toggleActivo(d),
                          )),
                    ],
                  ),
                ),
    );
  }
}

class _DuenoCard extends StatelessWidget {
  const _DuenoCard({
    required this.dueno,
    required this.onPassword,
    required this.onToggle,
  });

  final Dueno dueno;
  final VoidCallback onPassword;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final activo = dueno.isActive;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: activo
                ? AppColors.azulControl.withValues(alpha: 0.3)
                : AppColors.rojoAlerta.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: activo
                        ? AppColors.azulControl
                        : AppColors.rojoAlerta.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (dueno.nombre.isNotEmpty ? dueno.nombre : dueno.username)
                        .substring(0, 1)
                        .toUpperCase(),
                    style: AppTypography.titleMedium
                        .copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dueno.nombre,
                          style: AppTypography.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('@${dueno.username}',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textoClaroMedio)),
                    ],
                  ),
                ),
                if (!activo)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.rojoAlerta.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Inactivo',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.rojoAlerta)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.storefront_outlined,
                    size: 15, color: AppColors.textoClaroMedio),
                const SizedBox(width: 6),
                Text(
                  '${dueno.numRestaurantes} '
                  '${dueno.numRestaurantes == 1 ? "restaurante" : "restaurantes"}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textoClaroMedio),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onPassword,
                  icon: const Icon(Icons.key_outlined,
                      size: 16, color: AppColors.azulControl),
                  label: Text('Contraseña',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.azulControl)),
                ),
                Switch(
                  value: activo,
                  onChanged: (_) => onToggle(),
                  activeThumbColor: AppColors.verdeExito,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
