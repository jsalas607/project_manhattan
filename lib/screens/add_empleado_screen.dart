import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/app_text_field.dart';
import '../widgets/restaurant_header.dart';

enum _Modo { crear, existente }

class AddEmpleadoScreen extends StatefulWidget {
  const AddEmpleadoScreen({
    super.key,
    required this.restaurant,
    required this.user,
    required this.roles,
    required this.onAdded,
  });

  final Restaurant            restaurant;
  final AppUser               user;
  final List<RolRestaurante>  roles;
  final void Function(Empleado) onAdded;

  @override
  State<AddEmpleadoScreen> createState() => _AddEmpleadoScreenState();
}

class _AddEmpleadoScreenState extends State<AddEmpleadoScreen> {
  _Modo _modo = _Modo.crear;

  // Modo crear cuenta nueva
  final _nombreCtrl = TextEditingController();
  final _userCtrl   = TextEditingController();
  final _passCtrl   = TextEditingController();

  // Modo usuario existente
  final _buscarCtrl = TextEditingController();
  Map<String, String>? _foundUser;
  bool _searching = false;
  bool _searched  = false;

  late String _selectedRolId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedRolId = widget.roles.isNotEmpty ? widget.roles.first.id : '';
    for (final c in [_nombreCtrl, _userCtrl, _passCtrl, _buscarCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _buscarCtrl.dispose();
    super.dispose();
  }

  bool get _hasRol => widget.roles.isNotEmpty && _selectedRolId.isNotEmpty;

  // ── Modo crear cuenta ──────────────────────────────────────────────────────

  bool get _canCrear =>
      !_saving &&
      _hasRol &&
      _nombreCtrl.text.trim().isNotEmpty &&
      _userCtrl.text.trim().isNotEmpty &&
      _passCtrl.text.isNotEmpty;

  Future<void> _crear() async {
    if (!_canCrear) return;
    setState(() => _saving = true);
    try {
      final e = await MockGestionEmpleadoApi.crearUsuarioEmpleado(
        widget.restaurant.id,
        username: _userCtrl.text.trim().toLowerCase(),
        password: _passCtrl.text,
        nombre:   _nombreCtrl.text.trim(),
        rolId:    _selectedRolId,
      );
      _onDone(e, 'Empleado creado. Comparte usuario y contraseña con la persona.');
    } on ApiException catch (e) {
      _onError(e.statusCode == 409
          ? 'Ese usuario ya existe. Elige otro nombre de usuario.'
          : 'No se pudo crear: ${e.message}');
    }
  }

  // ── Modo usuario existente ─────────────────────────────────────────────────

  Future<void> _buscar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searched  = false;
      _foundUser = null;
    });
    final u = await MockGestionEmpleadoApi.buscarUsuarioPorUsername(
        widget.restaurant.id, _buscarCtrl.text);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searched  = true;
      _foundUser = u;
    });
  }

  Future<void> _agregarExistente() async {
    if (_foundUser == null || !_hasRol) return;
    setState(() => _saving = true);
    try {
      final e = await MockGestionEmpleadoApi.addEmpleado(
        widget.restaurant.id,
        userId: _foundUser!['id']!,
        nombre: _foundUser!['nombre']!,
        rolId:  _selectedRolId,
      );
      _onDone(e, 'Empleado agregado al restaurante.');
    } on ApiException catch (e) {
      _onError(e.statusCode == 409
          ? 'Ese usuario ya pertenece a este restaurante.'
          : 'No se pudo agregar: ${e.message}');
    }
  }

  // ── Helpers de resultado ───────────────────────────────────────────────────

  void _onDone(Empleado e, String msg) {
    if (!mounted) return;
    widget.onAdded(e);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.verdeExito,
        content: Text(msg,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textoOscuroAlto)),
      ),
    );
    Navigator.pop(context);
  }

  void _onError(String msg) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.rojoAlerta, content: Text(msg)),
    );
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
        title: Text('Añadir empleado', style: AppTypography.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RestaurantHeader(restaurant: widget.restaurant, user: widget.user),
            const SizedBox(height: 20),

            // ── Toggle de modo ────────────────────────────────────────────
            _ModoToggle(
              modo: _modo,
              onChanged: (m) => setState(() => _modo = m),
            ),
            const SizedBox(height: 20),

            // ── Selector de rol (compartido) ──────────────────────────────
            Text('Rol', style: AppTypography.labelLarge),
            const SizedBox(height: 8),
            if (widget.roles.isEmpty)
              _WarningBox(
                  text: 'No hay roles creados. Ve a la pantalla anterior y crea uno primero.')
            else
              _RolSelector(
                roles:    widget.roles,
                selected: _selectedRolId,
                onChanged: (id) => setState(() => _selectedRolId = id),
              ),
            const SizedBox(height: 24),

            if (_modo == _Modo.crear) ..._buildCrear() else ..._buildExistente(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── UI: modo crear cuenta ──────────────────────────────────────────────────

  List<Widget> _buildCrear() => [
        Text(
          'Crea la cuenta del empleado. Él entrará con el usuario y la '
          'contraseña que definas aquí.',
          style: AppTypography.caption
              .copyWith(color: AppColors.textoClaroMedio),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Nombre del empleado',
          controller: _nombreCtrl,
          hintText: 'Ej: Juan Pérez',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Usuario',
          controller: _userCtrl,
          hintText: 'Ej: juanp',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Contraseña',
          controller: _passCtrl,
          isPassword: true,
          hintText: 'Contraseña para el empleado',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _crear(),
        ),
        const SizedBox(height: 28),
        _PrimaryButton(
          label: 'Crear empleado',
          enabled: _canCrear,
          loading: _saving,
          onTap: _crear,
        ),
      ];

  // ── UI: modo usuario existente ─────────────────────────────────────────────

  List<Widget> _buildExistente() => [
        Text(
          'Busca por su nombre de usuario una persona ya registrada y agrégala '
          'a este restaurante con el rol que elijas.',
          style: AppTypography.caption
              .copyWith(color: AppColors.textoClaroMedio),
        ),
        const SizedBox(height: 16),
        Text('Nombre de usuario', style: AppTypography.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _buscarCtrl,
                style: AppTypography.bodyMedium,
                cursorColor: AppColors.naranjaAccion,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscar(),
                decoration: InputDecoration(
                  hintText: 'Ej: juanp',
                  hintStyle: AppTypography.caption.copyWith(
                      color: AppColors.textoClaroMedio.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: AppColors.azulControl.withValues(alpha: 0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.naranjaAccion),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: (_searching || _buscarCtrl.text.trim().isEmpty)
                  ? null
                  : _buscar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azulControl,
                disabledBackgroundColor:
                    AppColors.azulControl.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                elevation: 0,
              ),
              child: _searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Buscar',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textoClaroAlto)),
            ),
          ],
        ),
        if (_searched) ...[
          const SizedBox(height: 14),
          if (_foundUser == null)
            _ResultBox(
              color: AppColors.rojoAlerta,
              icon:  Icons.error_outline,
              text:  'No existe un usuario con ese nombre.',
            )
          else ...[
            _ResultBox(
              color: AppColors.verdeExito,
              icon:  Icons.check_circle_outline,
              text:  _foundUser!['nombre']!,
            ),
            const SizedBox(height: 20),
            _PrimaryButton(
              label: 'Agregar al restaurante',
              enabled: _hasRol && !_saving,
              loading: _saving,
              onTap: _agregarExistente,
            ),
          ],
        ],
      ];
}

// ---------------------------------------------------------------------------
// Toggle de modo (2 botones segmentados)
// ---------------------------------------------------------------------------

class _ModoToggle extends StatelessWidget {
  const _ModoToggle({required this.modo, required this.onChanged});
  final _Modo modo;
  final void Function(_Modo) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _seg('Crear cuenta nueva', _Modo.crear),
          _seg('Usuario existente', _Modo.existente),
        ],
      ),
    );
  }

  Widget _seg(String label, _Modo value) {
    final active = modo == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.naranjaAccion : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: active
                  ? AppColors.textoClaroAlto
                  : AppColors.textoClaroMedio,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Botón primario
// ---------------------------------------------------------------------------

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final String       label;
  final bool         enabled;
  final bool         loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.naranjaAccion,
            disabledBackgroundColor:
                AppColors.naranjaAccion.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.textoClaroAlto)),
        ),
      );
}

// ---------------------------------------------------------------------------
// Selector de roles (chips horizontales)
// ---------------------------------------------------------------------------

class _RolSelector extends StatelessWidget {
  const _RolSelector({
    required this.roles,
    required this.selected,
    required this.onChanged,
  });

  final List<RolRestaurante> roles;
  final String               selected;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: roles.map((r) {
          final isSelected = r.id == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(r.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.azulControl
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.azulControl
                        : AppColors.azulControl.withValues(alpha: 0.35),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  r.nombre,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isSelected
                        ? AppColors.textoClaroAlto
                        : AppColors.textoClaroMedio,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Caja de resultado
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
          border:       Border.all(color: color.withValues(alpha: 0.3)),
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
// Warning box
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
                        .copyWith(color: AppColors.naranjaAccion))),
          ],
        ),
      );
}
