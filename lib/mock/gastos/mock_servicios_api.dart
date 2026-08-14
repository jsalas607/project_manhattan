// API real: categorías de gasto de servicio personalizadas.
// Lo usa add_gasto_screen para guardar categorías nuevas creadas por el admin.

import '../../core/api_client.dart';

class MockServiciosApi {
  /// Categorías de servicio creadas por el admin para este restaurante.
  static Future<List<String>> getCategorias(String restaurantId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/servicios') as List;
    return json.map((e) => e as String).toList();
  }

  /// Agrega una categoría nueva (el backend evita duplicados).
  static Future<void> addCategoria(
      String restaurantId, String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return;
    await ApiClient.post(
      '/restaurants/$restaurantId/servicios',
      body: {'nombre': limpio},
    );
  }
}
