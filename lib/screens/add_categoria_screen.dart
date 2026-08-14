import 'package:flutter/material.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';

class AddCategoriaScreen extends StatefulWidget {
  const AddCategoriaScreen({
    super.key,
    required this.restaurant,
    required this.user,
    required this.onAdded,
  });

  final Restaurant              restaurant;
  final AppUser                 user;
  final void Function(Categoria) onAdded;

  @override
  State<AddCategoriaScreen> createState() => _AddCategoriaScreenState();
}

class _AddCategoriaScreenState extends State<AddCategoriaScreen> {
  final _nombreCtrl      = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  bool _saving  = false;
  bool _intento = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _intento = true);
    if (_nombreCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final c = await MockCategoriasApi.addCategoria(
      widget.restaurant.id,
      _nombreCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
    );
    if (!mounted) return;
    widget.onAdded(c);
    Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vacio = _intento && _nombreCtrl.text.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Añadir categoría', style: AppTypography.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Usuario + sucursal
            RestaurantHeader(restaurant: widget.restaurant, user: widget.user),
            const SizedBox(height: 28),

            // ── Foto + Nombre ─────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fotos',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textoClaroMedio)),
                    const SizedBox(height: 6),
                    _FotoPicker(),
                  ],
                ),
                const SizedBox(width: 14),

                // Nombre
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nombre',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textoClaroMedio)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nombreCtrl,
                        onChanged:  (_) => setState(() {}),
                        style:      AppTypography.bodyMedium,
                        decoration: InputDecoration(
                          hintText:  'Ej: Panadería, Bebidas...',
                          hintStyle: AppTypography.caption.copyWith(
                              color: AppColors.textoClaroMedio
                                  .withValues(alpha: 0.4)),
                          filled:    true,
                          fillColor: const Color(0xFF1E293B),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 13),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: vacio
                                  ? AppColors.rojoAlerta
                                  : AppColors.azulControl
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: vacio
                                  ? AppColors.rojoAlerta
                                  : AppColors.naranjaAccion,
                            ),
                          ),
                        ),
                      ),
                      if (vacio) ...[
                        const SizedBox(height: 4),
                        Text('Campo obligatorio',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.rojoAlerta)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Descripción ───────────────────────────────────────────────
            Text('Descripción',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textoClaroMedio)),
            const SizedBox(height: 6),
            TextField(
              controller: _descripcionCtrl,
              maxLines:   5,
              style:      AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText:  'Describe esta categoría (opcional)...',
                hintStyle: AppTypography.caption.copyWith(
                    color: AppColors.textoClaroMedio.withValues(alpha: 0.4)),
                filled:    true,
                fillColor: const Color(0xFF1E293B),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: AppColors.azulControl.withValues(alpha: 0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.naranjaAccion),
                ),
              ),
            ),
            const SizedBox(height: 36),

            // ── Guardar ───────────────────────────────────────────────────
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
                  : Text('GUARDAR',
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.textoClaroAlto)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selector de foto (placeholder)
// ---------------------------------------------------------------------------

class _FotoPicker extends StatefulWidget {
  @override
  State<_FotoPicker> createState() => _FotoPickerState();
}

class _FotoPickerState extends State<_FotoPicker> {
  bool _seleccionado = false;

  void _toggle() => setState(() => _seleccionado = !_seleccionado);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width:  80,
        height: 80,
        decoration: BoxDecoration(
          color: _seleccionado
              ? AppColors.naranjaAccion.withValues(alpha: 0.15)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _seleccionado
                ? AppColors.naranjaAccion.withValues(alpha: 0.6)
                : AppColors.azulControl.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _seleccionado
                  ? Icons.camera_alt
                  : Icons.camera_alt_outlined,
              color: _seleccionado
                  ? AppColors.naranjaAccion
                  : AppColors.textoClaroMedio.withValues(alpha: 0.45),
              size: 26,
            ),
            const SizedBox(height: 5),
            Text(
              _seleccionado ? 'Foto' : 'Añadir',
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                color: _seleccionado
                    ? AppColors.naranjaAccion
                    : AppColors.textoClaroMedio.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
