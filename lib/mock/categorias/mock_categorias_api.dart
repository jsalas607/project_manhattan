// API real para: categorias_screen.dart

import '../../core/api_client.dart';

class Categoria {
  final String  id;
  final String  nombre;
  final String? descripcion;
  final String? foto;

  const Categoria({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.foto,
  });

  static Categoria fromJson(Map<String, dynamic> j) => Categoria(
        id:          j['id'] as String,
        nombre:      j['nombre'] as String,
        descripcion: j['descripcion'] as String?,
        foto:        j['foto'] as String?,
      );
}

class MockCategoriasApi {
  static Future<List<Categoria>> getCategorias(String restaurantId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/categorias') as List;
    return json.map((e) => Categoria.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Categoria> addCategoria(
      String restaurantId, String nombre,
      {String? descripcion, String? foto}) async {
    final json = await ApiClient.post(
      '/restaurants/$restaurantId/categorias',
      body: {'nombre': nombre, 'descripcion': descripcion, 'foto': foto},
    ) as Map<String, dynamic>;
    return Categoria.fromJson(json);
  }

  static Future<void> deleteCategoria(
      String restaurantId, String categoriaId) async {
    await ApiClient.delete('/restaurants/$restaurantId/categorias/$categoriaId');
  }
}
