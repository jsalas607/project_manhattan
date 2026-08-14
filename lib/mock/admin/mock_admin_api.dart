// API real para: superadmin_hub_screen.dart, duenos_screen.dart
// Administración de dueños (los clientes que pagan el software).
// Solo el superadmin puede usar estos endpoints (el backend responde 403 al resto).

import '../../core/api_client.dart';

/// Un dueño = cliente que paga por usar el software.
class Dueno {
  final String id;
  final String username;
  final String nombre;
  final bool isActive;
  final int numRestaurantes;

  const Dueno({
    required this.id,
    required this.username,
    required this.nombre,
    required this.isActive,
    required this.numRestaurantes,
  });

  static Dueno fromJson(Map<String, dynamic> j) => Dueno(
        id:              j['id'] as String,
        username:        j['username'] as String,
        nombre:          j['nombre'] as String? ?? '',
        isActive:        j['isActive'] as bool? ?? true,
        numRestaurantes: j['numRestaurantes'] as int? ?? 0,
      );

  Dueno copyWith({bool? isActive}) => Dueno(
        id:              id,
        username:        username,
        nombre:          nombre,
        isActive:        isActive ?? this.isActive,
        numRestaurantes: numRestaurantes,
      );
}

class MockAdminApi {
  /// Lista de dueños con cuántos restaurantes tiene cada uno.
  static Future<List<Dueno>> getDuenos() async {
    final json = await ApiClient.get('/admin/users') as List;
    return json.map((e) => Dueno.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Crea un dueño nuevo (cliente que empieza a pagar).
  static Future<void> crearDueno({
    required String username,
    required String password,
    required String nombre,
  }) async {
    await ApiClient.post('/admin/users', body: {
      'username': username,
      'password': password,
      'nombre':   nombre,
      'isAdmin':  true,
    });
  }

  static Future<void> cambiarPassword(String userId, String password) async {
    await ApiClient.put('/admin/users/$userId/password',
        body: {'password': password});
  }

  /// Activa/desactiva a un dueño. Desactivado no puede entrar y su inquilino
  /// queda congelado (sus empleados tampoco), pero no se borra nada.
  static Future<Dueno> setActivo(String userId, bool isActive) async {
    final json = await ApiClient.patch('/admin/users/$userId/activo',
        body: {'isActive': isActive}) as Map<String, dynamic>;
    return Dueno.fromJson(json);
  }
}
