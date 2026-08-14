import 'package:flutter/material.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';
import 'admin_restaurante_screen.dart';
import 'atender_mesa_screen.dart';
import 'cartera_screen.dart';
import 'despachar_pedidos_screen.dart';
import 'create_restaurant_screen.dart';
import 'inventory_screen.dart';
import 'login_screen.dart';
import 'ver_menu_screen.dart';

class RestaurantViewScreen extends StatefulWidget {
  const RestaurantViewScreen({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser user;

  @override
  State<RestaurantViewScreen> createState() => _RestaurantViewScreenState();
}

class _RestaurantViewScreenState extends State<RestaurantViewScreen> {
  late Restaurant _restaurant;
  RestaurantStatus _status = RestaurantStatus.cerrado;
  bool _loadingStatus = true;

  @override
  void initState() {
    super.initState();
    _restaurant = widget.restaurant;
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final data = await MockRestaurantViewApi.get(_restaurant.id);
    if (!mounted) return;
    setState(() {
      _status = data.status;
      _loadingStatus = false;
    });
  }

  Future<void> _toggleStatus() async {
    final next = _status == RestaurantStatus.abierto
        ? RestaurantStatus.cerrado
        : RestaurantStatus.abierto;
    final result = await MockRestaurantViewApi.updateStatus(_restaurant.id, next);
    if (!mounted) return;
    setState(() => _status = result.status);
  }

  bool get _isOpen => _status == RestaurantStatus.abierto;

  Future<void> _goToEdit() async {
    final result = await Navigator.of(context).push<Restaurant>(
      MaterialPageRoute(
        builder: (_) => CreateRestaurantScreen(restaurant: _restaurant),
      ),
    );
    if (result != null) setState(() => _restaurant = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        automaticallyImplyLeading: false,
        // Solo hay flecha si de verdad se puede volver atrás (se llegó desde la
        // lista de restaurantes). Para quien entra directo a su único
        // restaurante, esta pantalla es la raíz: la flecha vaciaba el stack y
        // dejaba la pantalla en negro.
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon:
                    const Icon(Icons.arrow_back, color: AppColors.textoClaroAlto),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Vista del restaurante',
          style: AppTypography.titleLarge,
        ),
        actions: [
          // Status del restaurante
          GestureDetector(
            onTap: _loadingStatus ? null : _toggleStatus,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _isOpen
                    ? AppColors.verdeExito.withValues(alpha: 0.15)
                    : AppColors.rojoAlerta.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isOpen ? AppColors.verdeExito : AppColors.rojoAlerta,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isOpen
                          ? AppColors.verdeExito
                          : AppColors.rojoAlerta,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isOpen ? 'Abierto' : 'Cerrado',
                    style: AppTypography.caption.copyWith(
                      color: _isOpen
                          ? AppColors.verdeExito
                          : AppColors.rojoAlerta,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Editar restaurante — solo con permiso de administración
          if (widget.user.can(kSeccionAdministracion))
            IconButton(
              onPressed: _goToEdit,
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.textoClaroMedio,
                size: 20,
              ),
              tooltip: 'Editar restaurante',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Usuario + nombre de sucursal en una fila
            RestaurantHeader(restaurant: _restaurant, user: widget.user),
            const SizedBox(height: 20),

            // Funciones del restaurante — visibles según permisos del usuario
            // 1. Atender mesa
            if (widget.user.can(kSeccionAtenderMesa))
              _SectionCard(
                icon: Icons.table_restaurant_outlined,
                label: 'Atender mesa',
                description: 'Crear y gestionar órdenes',
                color: AppColors.naranjaAccion,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AtenderMesaScreen(
                      restaurant: _restaurant,
                      user:       widget.user,
                    ),
                  ),
                ),
              ),
            // 2. Despachar pedidos
            if (widget.user.can(kSeccionDespachar))
              _SectionCard(
                icon: Icons.delivery_dining_outlined,
                label: 'Despachar pedidos',
                description: 'Ver pedidos listos para entregar',
                color: const Color(0xFF8B5CF6),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DespacharPedidosScreen(
                      restaurant: _restaurant,
                      user:       widget.user,
                    ),
                  ),
                ),
              ),
            // 3. Cartera
            if (widget.user.can(kSeccionCartera))
              _SectionCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Cartera',
                description: 'Caja, ingresos y gastos',
                color: AppColors.verdeExito,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CarteraScreen(
                      restaurant: _restaurant,
                      user: widget.user,
                    ),
                  ),
                ),
              ),
            // 4. Ver menú
            if (widget.user.can(kSeccionVerMenu))
              _SectionCard(
                icon: Icons.menu_book_outlined,
                label: 'Ver menú',
                description: 'Platos, precios y categorías',
                color: AppColors.naranjaAccion,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VerMenuScreen(
                      restaurant: _restaurant,
                      user:       widget.user,
                    ),
                  ),
                ),
              ),
            // 5. Administrar inventario
            if (widget.user.can(kSeccionInventario))
              _SectionCard(
                icon: Icons.inventory_2_outlined,
                label: 'Administrar inventario',
                description: 'Ingredientes, stock y alertas',
                color: AppColors.azulControl,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => InventoryScreen(
                      restaurant: _restaurant,
                      user: widget.user,
                    ),
                  ),
                ),
              ),
            // 6. Administración de restaurante
            if (widget.user.can(kSeccionAdministracion))
              _SectionCard(
                icon: Icons.store_outlined,
                label: 'Administración de restaurante',
                description: 'Configuración, reportes y métricas',
                color: AppColors.azulControl,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminRestauranteScreen(
                      restaurant: _restaurant,
                      user:       widget.user,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Cerrar sesión al fondo
            TextButton.icon(
              onPressed: () async {
                await MockAuthApi.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout, color: AppColors.rojoAlerta, size: 18),
              label: Text(
                'Cerrar sesión',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.rojoAlerta,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets internos
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: color.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTypography.titleMedium),
                      const SizedBox(height: 2),
                      Text(description, style: AppTypography.caption),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textoClaroMedio.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
