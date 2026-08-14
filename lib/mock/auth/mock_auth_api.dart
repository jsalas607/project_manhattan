// API real para: login_screen.dart
// (conserva el nombre `Mock...` para no tener que tocar todas las pantallas
// que ya importan esta clase; los datos son 100% reales, no hay más mocks)

import '../../core/api_client.dart';
import '../../core/session.dart';

class AppUser {
  final String id;
  final String username;
  final String role;
  /// Permisos del usuario (claves de kPermisos). El admin los tiene todos.
  final List<String> permisos;
  /// Si es admin (dueño), ve la lista de sucursales. Si no, va directo a su restaurante.
  final bool isAdmin;
  /// La plataforma: ve el hub con el administrador de dueños.
  final bool isSuperadmin;
  /// Restaurante asignado para usuarios no-admin (null para admin).
  final String? restaurantId;

  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    this.permisos = const [],
    this.isAdmin = false,
    this.isSuperadmin = false,
    this.restaurantId,
  });

  /// El admin puede todo; los demás según su lista de permisos.
  bool can(String permiso) => isAdmin || permisos.contains(permiso);

  static AppUser fromJson(Map<String, dynamic> j) => AppUser(
        id:       j['id'] as String,
        username: j['username'] as String,
        role:     (j['title'] as String?)?.isNotEmpty == true
            ? j['title'] as String
            : (j['is_admin'] == true ? 'Administrador' : ''),
        isAdmin:      j['is_admin'] as bool? ?? false,
        isSuperadmin: j['is_superadmin'] as bool? ?? false,
      );
}

/// Una sucursal a la que el usuario tiene acceso, con su rol/permisos ahí.
class Membership {
  final String restaurantId;
  final String restaurantTitle;
  final String? roleId;
  final String? roleNombre;
  final List<String> permisos;

  const Membership({
    required this.restaurantId,
    required this.restaurantTitle,
    required this.roleId,
    required this.roleNombre,
    required this.permisos,
  });

  static Membership fromJson(Map<String, dynamic> j) => Membership(
        restaurantId:    j['restaurant_id'] as String,
        restaurantTitle: j['restaurant_title'] as String? ?? '',
        roleId:          j['role_id'] as String?,
        roleNombre:      j['role_nombre'] as String?,
        permisos:        List<String>.from(j['permisos'] as List? ?? const []),
      );
}

class MyRestaurantsResult {
  final bool isAdmin;
  final List<Membership> restaurants;
  const MyRestaurantsResult({required this.isAdmin, required this.restaurants});
}

class MockAuthApi {
  static Future<AppUser> login(String username, String password) async {
    final json = await ApiClient.post('/auth/login', body: {
      'username': username,
      'password': password,
    }) as Map<String, dynamic>;

    Session.token = json['access_token'] as String;
    final user = AppUser.fromJson(json['user'] as Map<String, dynamic>);
    Session.userId = user.id;
    await Session.save(Session.token!, user.id);
    return user;
  }

  static Future<AppUser> me() async {
    final json = await ApiClient.get('/auth/me') as Map<String, dynamic>;
    return AppUser.fromJson(json);
  }

  static Future<MyRestaurantsResult> myRestaurants() async {
    final json = await ApiClient.get('/auth/my-restaurants') as Map<String, dynamic>;
    final list = (json['restaurants'] as List)
        .map((e) => Membership.fromJson(e as Map<String, dynamic>))
        .toList();
    return MyRestaurantsResult(
      isAdmin: json['is_admin'] as bool? ?? false,
      restaurants: list,
    );
  }

  static Future<void> logout() async {
    await Session.clear();
  }
}
