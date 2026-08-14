import 'package:flutter/material.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import 'create_restaurant_screen.dart';
import 'profile_screen.dart';
import 'restaurant_view_screen.dart';

class RestaurantListScreen extends StatefulWidget {
  const RestaurantListScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  List<Restaurant> _restaurants = [];
  Map<String, Membership> _membershipsById = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    // Si no es admin, resolvemos el rol/permisos que tiene en CADA sucursal
    // (un usuario puede pertenecer a varias con roles distintos).
    if (!widget.user.isAdmin) {
      final my = await MockAuthApi.myRestaurants();
      _membershipsById = {for (final m in my.restaurants) m.restaurantId: m};
    }
    final data = await MockRestaurantApi.getAll();
    if (!mounted) return;
    setState(() {
      _restaurants = List.of(data);
      _loading = false;
    });
  }

  Future<void> _select(Restaurant r) async {
    var user = widget.user;
    if (!user.isAdmin) {
      final m = _membershipsById[r.id];
      user = AppUser(
        id:           user.id,
        username:     user.username,
        role:         m?.roleNombre ?? '',
        permisos:     m?.permisos ?? const [],
        isAdmin:      false,
        restaurantId: r.id,
      );
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantViewScreen(
          restaurant: r,
          user: user,
        ),
      ),
    );
  }

  Future<void> _duplicate(Restaurant r) async {
    final copy = await MockRestaurantApi.duplicate(r.id);
    if (!mounted) return;
    setState(() {
      final idx = _restaurants.indexWhere((x) => x.id == r.id);
      _restaurants.insert(idx + 1, copy);
    });
  }

  Future<void> _delete(Restaurant r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Borrar restaurante', style: AppTypography.titleMedium),
        content: Text(
          '¿Seguro que quieres borrar "${r.name}"?',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textoClaroMedio,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Borrar',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.rojoAlerta,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await MockRestaurantApi.delete(r.id);
    setState(() => _restaurants.removeWhere((x) => x.id == r.id));
  }

  Future<void> _add() async {
    final result = await Navigator.of(context).push<Restaurant>(
      MaterialPageRoute(
        builder: (_) => const CreateRestaurantScreen(),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _restaurants.add(result));
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        automaticallyImplyLeading: false,
        // Para el dueño esta pantalla es la raíz (sin flecha). El superadmin
        // llega desde su hub, así que ahí sí necesita volver.
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textoClaroAlto),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Row(
          children: [
            Text(
              'Lista de restaurantes',
              style: AppTypography.plusJakarta(
                size: 16,
                weight: FontWeight.w700,
                color: AppColors.textoClaroAlto,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.user.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textoClaroMedio,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sin notificaciones nuevas'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.textoClaroAlto,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.naranjaAccion),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
                itemCount: _restaurants.length + 1,
                itemBuilder: (ctx, index) {
                  if (index == _restaurants.length) {
                    return _AddCard(onTap: _add);
                  }
                  final r = _restaurants[index];
                  return _RestaurantCard(
                    restaurant: r,
                    onTap: () => _select(r),
                    onDuplicate: () => _duplicate(r),
                    onDelete: () => _delete(r),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openProfile,
        backgroundColor: AppColors.azulControl,
        child: const Icon(Icons.person, color: AppColors.textoClaroAlto),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.restaurant,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.azulControl.withValues(alpha: 0.3),
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 36, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.azulControl.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.store_outlined,
                      color: AppColors.azulControl,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    restaurant.name.trim().isNotEmpty
                        ? restaurant.name
                        : restaurant.title,
                    style: AppTypography.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant.isActive ? 'Activo' : 'Inactivo',
                    style: AppTypography.caption.copyWith(
                      color: restaurant.isActive
                          ? AppColors.verdeExito
                          : AppColors.rojoAlerta,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: PopupMenuButton<String>(
                color: const Color(0xFF0F172A),
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textoClaroMedio,
                  size: 18,
                ),
                onSelected: (value) {
                  if (value == 'duplicar') onDuplicate();
                  if (value == 'borrar') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'duplicar',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.copy,
                          size: 16,
                          color: AppColors.textoClaroMedio,
                        ),
                        const SizedBox(width: 8),
                        Text('Duplicar', style: AppTypography.bodyMedium),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'borrar',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppColors.rojoAlerta,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Borrar',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.rojoAlerta,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  const _AddCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.naranjaAccion.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.naranjaAccion.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: AppColors.naranjaAccion,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Añadir',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.naranjaAccion,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
