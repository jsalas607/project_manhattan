// API real para: gestion_empleado_screen.dart

import '../../core/api_client.dart';
import '../../core/api_exception.dart';

/// Claves de los permisos disponibles en la app
const kPermisos = <String>[
  'invitar_empleado',
  'crear_empleado',
  'configurar_metodos_pago',
  'ver_inventario',
  'eliminar_inventario',
  'crear_mesa',
  'cerrar_mesa',
  'crear_pedidos',
  'cerrar_pedidos',
  'ver_pedidos_vivo',
  'cobrar_mesa',
  'ver_cartera',
  'ver_menu',
  'administrar_restaurante',
];

/// Labels legibles para mostrar en UI
const kPermisosLabels = <String, String>{
  'invitar_empleado':        'Invitar empleado',
  'crear_empleado':          'Crear empleado',
  'configurar_metodos_pago': 'Configurar métodos de pago',
  'ver_inventario':          'Ver y añadir inventario',
  'eliminar_inventario':     'Eliminar producto del inventario',
  'crear_mesa':              'Crear mesa',
  'cerrar_mesa':             'Cerrar mesa',
  'crear_pedidos':           'Crear pedidos',
  'cerrar_pedidos':          'Cerrar pedidos',
  'ver_pedidos_vivo':        'Ver lista de pedidos en vivo',
  'cobrar_mesa':             'Cobrar mesa',
  'ver_cartera':             'Ver cartera y caja',
  'ver_menu':                'Ver menú',
  'administrar_restaurante': 'Administración del restaurante',
};

// ---------------------------------------------------------------------------
// Secciones de la app → permiso requerido para verlas
// (usado por RestaurantViewScreen para mostrar/ocultar tarjetas)
// ---------------------------------------------------------------------------

const kSeccionAtenderMesa   = 'crear_mesa';
const kSeccionDespachar     = 'ver_pedidos_vivo';
const kSeccionCartera       = 'ver_cartera';
const kSeccionCobrar        = 'cobrar_mesa';
const kSeccionVerMenu       = 'ver_menu';
const kSeccionInventario    = 'ver_inventario';
const kSeccionAdministracion = 'administrar_restaurante';

// ---------------------------------------------------------------------------
// Modelos
// ---------------------------------------------------------------------------

class Empleado {
  final String id;     // id de la membership (usado para editar/eliminar)
  final String userId; // id de la cuenta de usuario (para admin: password/borrar)
  final String nombre;
  final String rolId;

  const Empleado({
    required this.id,
    required this.userId,
    required this.nombre,
    required this.rolId,
  });

  Empleado copyWith({String? nombre, String? rolId}) => Empleado(
        id:     id,
        userId: userId,
        nombre: nombre ?? this.nombre,
        rolId:  rolId  ?? this.rolId,
      );

  static Empleado fromJson(Map<String, dynamic> j) => Empleado(
        id:     j['id'] as String,
        userId: j['userId'] as String? ?? '',
        nombre: j['nombre'] as String,
        rolId:  j['rolId'] as String? ?? '',
      );
}

class RolRestaurante {
  final String       id;
  final String       nombre;
  final List<String> permisos;

  const RolRestaurante({
    required this.id,
    required this.nombre,
    required this.permisos,
  });

  static RolRestaurante fromJson(Map<String, dynamic> j) => RolRestaurante(
        id:       j['id'] as String,
        nombre:   j['nombre'] as String,
        permisos: List<String>.from(j['permisos'] as List? ?? const []),
      );
}

class MockGestionEmpleadoApi {
  // ── Empleados ──────────────────────────────────────────────────────────────

  static Future<List<Empleado>> getEmpleados(String restaurantId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/empleados') as List;
    return json.map((e) => Empleado.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Busca un usuario registrado por su ID. Retorna null si no existe.
  static Future<Map<String, String>?> findUsuario(
      String restaurantId, String userId) async {
    try {
      final json = await ApiClient.get(
        '/restaurants/$restaurantId/usuarios/${userId.trim()}',
      ) as Map<String, dynamic>?;
      if (json == null) return null;
      return {'id': json['id'] as String, 'nombre': json['nombre'] as String};
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Busca un usuario global por su username. Retorna null si no existe.
  static Future<Map<String, String>?> buscarUsuarioPorUsername(
      String restaurantId, String username) async {
    try {
      final json = await ApiClient.get(
        '/restaurants/$restaurantId/usuarios',
        query: {'username': username.trim()},
      ) as Map<String, dynamic>?;
      if (json == null) return null;
      return {'id': json['id'] as String, 'nombre': json['nombre'] as String};
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  static Future<Empleado> addEmpleado(
    String restaurantId, {
    required String userId,
    required String nombre,
    required String rolId,
  }) async {
    final json = await ApiClient.post(
      '/restaurants/$restaurantId/empleados',
      body: {'userId': userId, 'nombre': nombre, 'rolId': rolId},
    ) as Map<String, dynamic>;
    return Empleado.fromJson(json);
  }

  /// El dueño crea la cuenta del empleado (usuario + contraseña) y le asigna
  /// rol en un solo paso. El empleado entra con esas credenciales.
  static Future<Empleado> crearUsuarioEmpleado(
    String restaurantId, {
    required String username,
    required String password,
    required String nombre,
    required String rolId,
  }) async {
    final json = await ApiClient.post(
      '/restaurants/$restaurantId/empleados/nuevo-usuario',
      body: {
        'username': username,
        'password': password,
        'nombre': nombre,
        'rolId': rolId,
      },
    ) as Map<String, dynamic>;
    return Empleado.fromJson(json);
  }

  static Future<Empleado> editEmpleado(
    String restaurantId, {
    required String empleadoId,
    required String nombre,
    required String rolId,
  }) async {
    final json = await ApiClient.put(
      '/restaurants/$restaurantId/empleados/$empleadoId',
      body: {'nombre': nombre, 'rolId': rolId},
    ) as Map<String, dynamic>;
    return Empleado.fromJson(json);
  }

  static Future<void> removeEmpleado(
      String restaurantId, String empleadoId) async {
    await ApiClient.delete('/restaurants/$restaurantId/empleados/$empleadoId');
  }

  // ── Gestión de cuentas (solo admin) ────────────────────────────────────────

  /// Cambia la contraseña de la cuenta de un usuario (solo admin).
  static Future<void> cambiarPasswordUsuario(
      String userId, String password) async {
    await ApiClient.put(
      '/admin/users/$userId/password',
      body: {'password': password},
    );
  }

  /// Elimina la cuenta de un usuario del sistema: sale de TODOS los
  /// restaurantes (solo admin; no permite borrar admins).
  static Future<void> eliminarUsuario(String userId) async {
    await ApiClient.delete('/admin/users/$userId');
  }

  // ── Roles ──────────────────────────────────────────────────────────────────

  static Future<List<RolRestaurante>> getRoles(String restaurantId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/roles') as List;
    return json.map((e) => RolRestaurante.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<RolRestaurante> addRol(
    String restaurantId, {
    required String       nombre,
    required List<String> permisos,
  }) async {
    final json = await ApiClient.post(
      '/restaurants/$restaurantId/roles',
      body: {'nombre': nombre, 'permisos': permisos},
    ) as Map<String, dynamic>;
    return RolRestaurante.fromJson(json);
  }

  static Future<void> removeRol(String restaurantId, String rolId) async {
    await ApiClient.delete('/restaurants/$restaurantId/roles/$rolId');
  }
}
