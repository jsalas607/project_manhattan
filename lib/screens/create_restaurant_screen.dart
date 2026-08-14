import 'package:flutter/material.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/app_text_field.dart';

const _defaultPaymentMethods = [
  'efectivo',
  'nequi',
  'datafono',
  'bancolombia',
  'daviplata',
];

class CreateRestaurantScreen extends StatefulWidget {
  const CreateRestaurantScreen({super.key, this.restaurant});

  /// Si se pasa un restaurante existente, la pantalla funciona como editor.
  final Restaurant? restaurant;

  @override
  State<CreateRestaurantScreen> createState() => _CreateRestaurantScreenState();
}

class _CreateRestaurantScreenState extends State<CreateRestaurantScreen> {
  final _titleCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _customMethodCtrl = TextEditingController();

  late Set<String> _selectedMethods;
  late List<String> _allMethods;
  bool _loading = false;

  bool get _isEditing => widget.restaurant != null;

  @override
  void initState() {
    super.initState();
    final r = widget.restaurant;
    _titleCtrl.text = r?.title ?? '';
    _nameCtrl.text = r?.name ?? '';
    _descCtrl.text = r?.description ?? '';
    _countryCtrl.text = r?.country ?? '';
    _cityCtrl.text = r?.city ?? '';
    _addressCtrl.text = r?.address ?? '';

    _selectedMethods = Set.of(r?.paymentMethods ?? []);
    _allMethods = List.of(_defaultPaymentMethods);
    // Añadir métodos custom del restaurante que no estén en la lista por defecto
    for (final m in _selectedMethods) {
      if (!_allMethods.contains(m)) _allMethods.add(m);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _countryCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _customMethodCtrl.dispose();
    super.dispose();
  }

  void _toggleMethod(String method) {
    setState(() {
      if (_selectedMethods.contains(method)) {
        _selectedMethods.remove(method);
      } else {
        _selectedMethods.add(method);
      }
    });
  }

  void _addCustomMethod() {
    final value = _customMethodCtrl.text.trim().toLowerCase();
    if (value.isEmpty || _allMethods.contains(value)) return;
    setState(() {
      _allMethods.add(value);
      _selectedMethods.add(value);
      _customMethodCtrl.clear();
    });
  }

  bool _isCustom(String m) => !_defaultPaymentMethods.contains(m);

  void _deleteMethod(String m) {
    setState(() {
      _allMethods.remove(m);
      _selectedMethods.remove(m);
    });
  }

  Future<void> _onSave() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es obligatorio')),
      );
      return;
    }

    setState(() => _loading = true);

    final data = Restaurant(
      id: widget.restaurant?.id ?? '',
      title: title,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      country: _countryCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      paymentMethods: _selectedMethods.toList(),
    );

    final result = _isEditing
        ? await MockRestaurantApi.update(data)
        : await MockRestaurantApi.create(data);

    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditing ? 'Editar restaurante' : 'Crear restaurante',
          style: AppTypography.titleLarge,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título
            AppTextField(
              label: 'Título',
              controller: _titleCtrl,
              hintText: 'Ej: Sucursal Centro',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),

            // Foto + Nombre del negocio
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Foto placeholder
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Foto', style: AppTypography.labelLarge),
                    const SizedBox(height: 6),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.azulControl.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.textoClaroMedio,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Nombre del negocio
                Expanded(
                  child: AppTextField(
                    label: 'Nombre del negocio',
                    controller: _nameCtrl,
                    hintText: 'Ej: La Esquina',
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Descripción
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Descripción', style: AppTypography.labelLarge),
                const SizedBox(height: 6),
                TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  style: AppTypography.bodyLarge,
                  cursorColor: AppColors.naranjaAccion,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Describe el restaurante...',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textoClaroMedio.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.naranjaAccion,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // País + Ciudad
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'País',
                    controller: _countryCtrl,
                    hintText: 'Colombia',
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    label: 'Ciudad',
                    controller: _cityCtrl,
                    hintText: 'Bogotá',
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Dirección
            AppTextField(
              label: 'Dirección',
              controller: _addressCtrl,
              hintText: 'Calle 123 # 45-67',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),

            // Métodos de pago
            Text('Métodos de pago', style: AppTypography.labelLarge),
            const SizedBox(height: 4),
            Text(
              'Lo que selecciones se usará como método de cobro',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._allMethods.map((method) => _PaymentChip(
                      label: method,
                      selected: _selectedMethods.contains(method),
                      onTap: () => _toggleMethod(method),
                      onDelete:
                          _isCustom(method) ? () => _deleteMethod(method) : null,
                    )),
                _AddMethodChip(
                  controller: _customMethodCtrl,
                  onAdd: _addCustomMethod,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Botón guardar
            ElevatedButton(
              onPressed: _loading ? null : _onSave,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textoClaroAlto,
                      ),
                    )
                  : Text(_isEditing ? 'Guardar cambios' : 'Crear restaurante'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets internos
// ---------------------------------------------------------------------------

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final textColor =
        selected ? AppColors.naranjaAccion : AppColors.textoClaroMedio;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(
            left: 16, top: 10, bottom: 10, right: onDelete == null ? 16 : 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.naranjaAccion.withValues(alpha: 0.15)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? AppColors.naranjaAccion
                : AppColors.azulControl.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTypography.labelLarge.copyWith(color: textColor)),
            if (onDelete != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: const Icon(Icons.close,
                    size: 15, color: AppColors.rojoAlerta),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddMethodChip extends StatefulWidget {
  const _AddMethodChip({required this.controller, required this.onAdd});

  final TextEditingController controller;
  final VoidCallback onAdd;

  @override
  State<_AddMethodChip> createState() => _AddMethodChipState();
}

class _AddMethodChipState extends State<_AddMethodChip> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return GestureDetector(
        onTap: () => setState(() => _editing = true),
        child: Container(
          width:  40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.textoClaroMedio.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.add,
            size: 18,
            color: AppColors.textoClaroMedio,
          ),
        ),
      );
    }

    return SizedBox(
      width: 140,
      height: 40,
      child: TextField(
        controller: widget.controller,
        autofocus: true,
        style: AppTypography.bodyMedium,
        cursorColor: AppColors.naranjaAccion,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          widget.onAdd();
          setState(() => _editing = false);
        },
        decoration: InputDecoration(
          hintText: 'Método...',
          hintStyle: AppTypography.caption,
          filled: true,
          fillColor: const Color(0xFF1E293B),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          suffixIcon: IconButton(
            icon: const Icon(Icons.check, size: 16, color: AppColors.verdeExito),
            onPressed: () {
              widget.onAdd();
              setState(() => _editing = false);
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.naranjaAccion),
          ),
        ),
      ),
    );
  }
}
