// API real para: gestion_menu_screen.dart

import '../../core/api_client.dart';

// ---------------------------------------------------------------------------
// Modelos de receta (para productos compuestos)
// ---------------------------------------------------------------------------

class OpcionReceta {
  final String nombre;
  const OpcionReceta({required this.nombre});

  static OpcionReceta fromJson(Map<String, dynamic> j) =>
      OpcionReceta(nombre: j['nombre'] as String);

  Map<String, dynamic> toJson() => {'nombre': nombre};
}

class IngredienteReceta {
  final String           nombre;
  final bool             obligatorio; // true = auto-descuenta (1 opción), false = mesera elige
  final List<OpcionReceta> opciones;
  const IngredienteReceta({
    required this.nombre,
    required this.obligatorio,
    required this.opciones,
  });

  static IngredienteReceta fromJson(Map<String, dynamic> j) => IngredienteReceta(
        nombre:      j['nombre'] as String,
        obligatorio: j['obligatorio'] as bool? ?? false,
        opciones: (j['opciones'] as List? ?? const [])
            .map((e) => OpcionReceta.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'nombre':      nombre,
        'obligatorio': obligatorio,
        'opciones':    opciones.map((o) => o.toJson()).toList(),
      };
}

// ---------------------------------------------------------------------------
// Modelo Producto
// ---------------------------------------------------------------------------

class Producto {
  final String  id;
  final String  nombre;
  final double  precio;
  final String  categoriaId;
  final String? foto;
  final bool    visible;
  final List<IngredienteReceta> ingredientes; // solo para compuestos

  const Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.categoriaId,
    this.foto,
    this.visible = true,
    this.ingredientes = const [],
  });

  bool get esCompuesto => ingredientes.isNotEmpty;

  Producto copyWith({
    String?  nombre,
    double?  precio,
    String?  categoriaId,
    String?  foto,
    bool?    visible,
    List<IngredienteReceta>? ingredientes,
  }) =>
      Producto(
        id:          id,
        nombre:      nombre      ?? this.nombre,
        precio:      precio      ?? this.precio,
        categoriaId: categoriaId ?? this.categoriaId,
        foto:        foto        ?? this.foto,
        visible:     visible     ?? this.visible,
        ingredientes: ingredientes ?? this.ingredientes,
      );

  static Producto fromJson(Map<String, dynamic> j) => Producto(
        id:          j['id'] as String,
        nombre:      j['nombre'] as String,
        precio:      (j['precio'] as num).toDouble(),
        categoriaId: j['categoriaId'] as String,
        foto:        j['foto'] as String?,
        visible:     j['visible'] as bool? ?? true,
        ingredientes: (j['ingredientes'] as List? ?? const [])
            .map((e) => IngredienteReceta.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MockMenuApi {
  static Future<List<Producto>> getProductos(String restaurantId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/productos') as List;
    return json.map((e) => Producto.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Producto> addProducto(
    String restaurantId, {
    required String  nombre,
    required double  precio,
    required String  categoriaId,
    String?          foto,
    List<IngredienteReceta> ingredientes = const [],
  }) async {
    final json = await ApiClient.post(
      '/restaurants/$restaurantId/productos',
      body: {
        'nombre':      nombre,
        'precio':      precio,
        'categoriaId': categoriaId,
        'foto':        foto,
        'ingredientes': ingredientes.map((i) => i.toJson()).toList(),
      },
    ) as Map<String, dynamic>;
    return Producto.fromJson(json);
  }

  static Future<Producto> toggleVisible(
      String restaurantId, String productoId) async {
    final json = await ApiClient.patch(
      '/restaurants/$restaurantId/productos/$productoId/visible',
    ) as Map<String, dynamic>;
    return Producto.fromJson(json);
  }

  static Future<void> deleteProducto(
      String restaurantId, String productoId) async {
    await ApiClient.delete('/restaurants/$restaurantId/productos/$productoId');
  }
}
