import 'package:flutter/material.dart';

import '../mock/mock_api.dart';
import 'restaurant_list_screen.dart';
import 'restaurant_view_screen.dart';
import 'superadmin_hub_screen.dart';

/// El usuario está autenticado correctamente pero no tiene ningún
/// restaurante asignado (o el asignado ya no existe).
class NoAccessException implements Exception {
  final String message;
  const NoAccessException(this.message);
  @override
  String toString() => message;
}

/// Decide a qué pantalla llevar a un usuario ya autenticado:
/// - Superadmin (la plataforma) → hub: usar la app o administrar dueños.
/// - Admin (dueño) → lista de sucursales.
/// - No-admin con 1 sola sucursal → directo a esa sucursal (con su rol/permisos).
/// - No-admin con varias sucursales → lista (resuelve el rol al elegir).
///
/// Lanza una excepción con un mensaje legible si el usuario no tiene acceso
/// a ningún restaurante o el restaurante asignado no existe.
Future<Widget> resolveHomeScreen(AppUser user) async {
  // El superadmin es también isAdmin, así que va primero.
  if (user.isSuperadmin) {
    return SuperadminHubScreen(user: user);
  }

  if (user.isAdmin) {
    return RestaurantListScreen(user: user);
  }

  final myRestaurants = await MockAuthApi.myRestaurants();

  if (myRestaurants.restaurants.isEmpty) {
    throw const NoAccessException('Tu usuario no tiene acceso a ningún restaurante');
  }

  if (myRestaurants.restaurants.length == 1) {
    final m = myRestaurants.restaurants.first;
    final scopedUser = AppUser(
      id:           user.id,
      username:     user.username,
      role:         m.roleNombre ?? '',
      permisos:     m.permisos,
      isAdmin:      false,
      restaurantId: m.restaurantId,
    );
    final restaurant = await MockRestaurantApi.getById(m.restaurantId);
    if (restaurant == null) {
      throw const NoAccessException('No se encontró el restaurante asignado');
    }
    return RestaurantViewScreen(restaurant: restaurant, user: scopedUser);
  }

  return RestaurantListScreen(user: user);
}
