// API real para: atender_mesa_screen.dart

import '../../core/api_client.dart';

class Mesa {
  final String id;
  final int    orden;    // auto-incremental global
  final int    numero;   // número físico de la mesa
  final String nombre;   // nombre del cliente
  final bool   atendida; // false = abierta, true = atendida/cerrada

  const Mesa({
    required this.id,
    required this.orden,
    required this.numero,
    required this.nombre,
    required this.atendida,
  });

  Mesa copyWith({
    String? id,
    int?    orden,
    int?    numero,
    String? nombre,
    bool?   atendida,
  }) =>
      Mesa(
        id:       id       ?? this.id,
        orden:    orden    ?? this.orden,
        numero:   numero   ?? this.numero,
        nombre:   nombre   ?? this.nombre,
        atendida: atendida ?? this.atendida,
      );

  static Mesa fromJson(Map<String, dynamic> j) => Mesa(
        id:       j['id'] as String,
        orden:    j['orden'] as int,
        numero:   j['numero'] as int,
        nombre:   j['nombre'] as String? ?? '',
        atendida: j['atendida'] as bool? ?? false,
      );
}

class MockAtenderMesaApi {
  static Future<List<Mesa>> getMesas(String restaurantId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/mesas') as List;
    return json.map((e) => Mesa.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Mesa> addMesa(
    String restaurantId, {
    required int    numero,
    required String nombre,
  }) async {
    final json = await ApiClient.post(
      '/restaurants/$restaurantId/mesas',
      body: {'numero': numero, 'nombre': nombre},
    ) as Map<String, dynamic>;
    return Mesa.fromJson(json);
  }

  /// Elimina una mesa (p. ej. al cobrarla).
  static Future<void> removeMesa(
      String restaurantId, String mesaId) async {
    await ApiClient.delete('/restaurants/$restaurantId/mesas/$mesaId');
  }

  static Future<Mesa> toggleAtendida(
      String restaurantId, String mesaId) async {
    final json = await ApiClient.patch(
      '/restaurants/$restaurantId/mesas/$mesaId/atendida',
    ) as Map<String, dynamic>;
    return Mesa.fromJson(json);
  }
}
