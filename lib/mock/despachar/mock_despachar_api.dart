// API real para: despachar_pedidos_screen.dart

import 'package:flutter/material.dart';

import '../../core/api_client.dart';

// ---------------------------------------------------------------------------
// Catálogos de íconos y colores que el admin puede elegir para una pantalla
// (viven solo en el cliente; el backend solo guarda el índice)
// ---------------------------------------------------------------------------

const kDespachoIconos = <IconData>[
  Icons.soup_kitchen,       // 0
  Icons.local_cafe,         // 1
  Icons.bakery_dining,      // 2
  Icons.kitchen,            // 3
  Icons.lunch_dining,       // 4
  Icons.local_bar,          // 5
  Icons.icecream,           // 6
  Icons.ramen_dining,       // 7
  Icons.outdoor_grill,      // 8
  Icons.tapas,              // 9
];

const kDespachoColores = <Color>[
  Color(0xFFF97316), // naranja
  Color(0xFF1E3A8A), // azul
  Color(0xFF8B5CF6), // morado
  Color(0xFF10B981), // verde
  Color(0xFFEC4899), // rosa
  Color(0xFFF59E0B), // ámbar
];

// ---------------------------------------------------------------------------
// Modelo de pantalla de despacho (la crea el admin)
// ---------------------------------------------------------------------------

class PantallaDespacho {
  final String       id;
  final String       nombre;
  final List<String> categoriaIds;
  final int          iconoIndex;
  final int          colorIndex;

  const PantallaDespacho({
    required this.id,
    required this.nombre,
    required this.categoriaIds,
    required this.iconoIndex,
    required this.colorIndex,
  });

  IconData get icono => kDespachoIconos[iconoIndex % kDespachoIconos.length];
  Color    get color => kDespachoColores[colorIndex % kDespachoColores.length];

  static PantallaDespacho fromJson(Map<String, dynamic> j) => PantallaDespacho(
        id:           j['id'] as String,
        nombre:       j['nombre'] as String,
        categoriaIds: List<String>.from(j['categoriaIds'] as List? ?? const []),
        iconoIndex:   j['iconoIndex'] as int? ?? 0,
        colorIndex:   j['colorIndex'] as int? ?? 0,
      );
}

// Nota: los modelos de pedido (ItemPedido, PedidoActivo) y su almacén viven
// en mock/pedidos/mock_pedidos_api.dart — el despacho los lee desde ahí.

class MockDespacharApi {
  // ── Pantallas de despacho ─────────────────────────────────────────────────

  static Future<List<PantallaDespacho>> getPantallas(
      String restaurantId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/despacho') as List;
    return json.map((e) => PantallaDespacho.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<PantallaDespacho> addPantalla(
    String restaurantId, {
    required String       nombre,
    required List<String> categoriaIds,
    required int          iconoIndex,
    required int          colorIndex,
  }) async {
    final json = await ApiClient.post(
      '/restaurants/$restaurantId/despacho',
      body: {
        'nombre':       nombre,
        'categoriaIds': categoriaIds,
        'iconoIndex':   iconoIndex,
        'colorIndex':   colorIndex,
      },
    ) as Map<String, dynamic>;
    return PantallaDespacho.fromJson(json);
  }

  static Future<void> deletePantalla(
      String restaurantId, String pantallaId) async {
    await ApiClient.delete('/restaurants/$restaurantId/despacho/$pantallaId');
  }
}
