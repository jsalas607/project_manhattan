import 'package:flutter/material.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';

class AddPantallaDespachoScreen extends StatefulWidget {
  const AddPantallaDespachoScreen({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser    user;

  @override
  State<AddPantallaDespachoScreen> createState() =>
      _AddPantallaDespachoScreenState();
}

class _AddPantallaDespachoScreenState
    extends State<AddPantallaDespachoScreen> {
  final _nombreCtrl = TextEditingController();

  final Set<String> _categoriaIds = {};
  int  _iconoIndex = 0;
  int  _colorIndex = 0;
  bool _saving     = false;
  bool _intento    = false;

  List<Categoria> _categorias = [];
  bool            _loading    = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cats = await MockCategoriasApi.getCategorias(widget.restaurant.id);
    if (!mounted) return;
    setState(() {
      _categorias = cats;
      _loading    = false;
    });
  }

  bool _validar() =>
      _nombreCtrl.text.trim().isNotEmpty && _categoriaIds.isNotEmpty;

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() => _intento = true);
    if (!_validar()) return;
    setState(() => _saving = true);

    final pantalla = await MockDespacharApi.addPantalla(
      widget.restaurant.id,
      nombre:       _nombreCtrl.text.trim(),
      categoriaIds: _categoriaIds.toList(),
      iconoIndex:   _iconoIndex,
      colorIndex:   _colorIndex,
    );
    if (!mounted) return;
    Navigator.pop(context, pantalla);
  }

  @override
  Widget build(BuildContext context) {
    final color       = kDespachoColores[_colorIndex];
    final errorNombre = _intento && _nombreCtrl.text.trim().isEmpty;
    final errorCats   = _intento && _categoriaIds.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.fondoOscuro,
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Nueva pantalla', style: AppTypography.titleLarge),
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
                  // Vista previa
                  Center(
                    child: Container(
                      width:  72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: color.withValues(alpha: 0.5)),
                      ),
                      child: Icon(kDespachoIconos[_iconoIndex],
                          color: color, size: 38),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Nombre
                  _LabeledField(
                    label: 'Nombre de la pantalla',
                    child: TextField(
                      controller: _nombreCtrl,
                      onChanged:  (_) => setState(() {}),
                      style:      AppTypography.bodyMedium,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDec(
                        hint:  'Ej: Cocina, Cafetería, Bar...',
                        error: errorNombre,
                      ),
                    ),
                  ),
                  if (errorNombre) ...[
                    const SizedBox(height: 4),
                    _errorText('Campo obligatorio'),
                  ],
                  const SizedBox(height: 22),

                  // Categorías
                  Row(children: [
                    Text('Categorías que muestra',
                        style: AppTypography.labelLarge),
                    const SizedBox(width: 6),
                    if (_categoriaIds.isNotEmpty)
                      Text('(${_categoriaIds.length})',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.naranjaAccion)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'Solo los productos de estas categorías aparecerán en la pantalla.',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textoClaroMedio),
                  ),
                  const SizedBox(height: 12),

                  if (_categorias.isEmpty)
                    Text('No hay categorías creadas.',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textoClaroMedio))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categorias.map((cat) {
                        final sel = _categoriaIds.contains(cat.id);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (sel) {
                              _categoriaIds.remove(cat.id);
                            } else {
                              _categoriaIds.add(cat.id);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.naranjaAccion
                                      .withValues(alpha: 0.15)
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sel
                                    ? AppColors.naranjaAccion
                                    : AppColors.azulControl
                                        .withValues(alpha: 0.3),
                                width: sel ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (sel) ...[
                                  const Icon(Icons.check,
                                      size: 14,
                                      color: AppColors.naranjaAccion),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  cat.nombre,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: sel
                                        ? AppColors.naranjaAccion
                                        : AppColors.textoClaroMedio,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  if (errorCats) ...[
                    const SizedBox(height: 6),
                    _errorText('Selecciona al menos una categoría'),
                  ],
                  const SizedBox(height: 22),

                  // Ícono
                  Text('Ícono', style: AppTypography.labelLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children:
                        List.generate(kDespachoIconos.length, (i) {
                      final sel = _iconoIndex == i;
                      return GestureDetector(
                        onTap: () => setState(() => _iconoIndex = i),
                        child: Container(
                          width:  48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: sel
                                ? color.withValues(alpha: 0.15)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel
                                  ? color
                                  : AppColors.azulControl
                                      .withValues(alpha: 0.25),
                              width: sel ? 2 : 1,
                            ),
                          ),
                          child: Icon(kDespachoIconos[i],
                              color: sel
                                  ? color
                                  : AppColors.textoClaroMedio,
                              size: 24),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),

                  // Color
                  Text('Color', style: AppTypography.labelLarge),
                  const SizedBox(height: 12),
                  Row(
                    children:
                        List.generate(kDespachoColores.length, (i) {
                      final c   = kDespachoColores[i];
                      final sel = _colorIndex == i;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => setState(() => _colorIndex = i),
                          child: Container(
                            width:  40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: sel
                                    ? AppColors.textoClaroAlto
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: sel
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                        ),
                      );
                    }),
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('CREAR PANTALLA',
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
// Helpers
// ---------------------------------------------------------------------------

InputDecoration _inputDec({required String hint, bool error = false}) =>
    InputDecoration(
      hintText:  hint,
      hintStyle: AppTypography.caption.copyWith(
          color: AppColors.textoClaroMedio.withValues(alpha: 0.4)),
      filled:    true,
      fillColor: const Color(0xFF1E293B),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    );

Widget _errorText(String msg) => Text(
      msg,
      style: AppTypography.caption.copyWith(color: AppColors.rojoAlerta),
    );

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
