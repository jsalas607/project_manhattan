// API real: almacén central de pedidos por mesa.
// Lo escriben atender_mesa / mesa_detalle; lo lee despachar_pedidos.

import '../../core/api_client.dart';

// ---------------------------------------------------------------------------
// Modelos
// ---------------------------------------------------------------------------

class ItemPedido {
  final String productoId;
  final String productoNombre;
  final String categoriaId;
  final int    cantidad;
  final String config; // "Proteína: Pollo · Acompañante: Sopa" (vacío si simple)

  const ItemPedido({
    required this.productoId,
    required this.productoNombre,
    required this.categoriaId,
    required this.cantidad,
    this.config = '',
  });

  static ItemPedido fromJson(Map<String, dynamic> j) => ItemPedido(
        productoId:     j['productoId'] as String,
        productoNombre: j['productoNombre'] as String,
        categoriaId:    j['categoriaId'] as String? ?? '',
        cantidad:       j['cantidad'] as int? ?? 1,
        config:         j['config'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'productoId':     productoId,
        'productoNombre': productoNombre,
        'categoriaId':    categoriaId,
        'cantidad':       cantidad,
        'config':         config,
      };
}

class PedidoActivo {
  final String           id;        // = mesaId
  final int              mesaNumero;
  final int              orden;
  final List<ItemPedido> items;

  const PedidoActivo({
    required this.id,
    required this.mesaNumero,
    required this.orden,
    required this.items,
  });

  static PedidoActivo fromJson(Map<String, dynamic> j) => PedidoActivo(
        id:         j['id'] as String,
        mesaNumero: j['mesaNumero'] as int,
        orden:      j['orden'] as int,
        items: (j['items'] as List)
            .map((e) => ItemPedido.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MockPedidosApi {
  // Flags "listo" por posición, cacheados desde la última respuesta del
  // backend (el modelo ItemPedido de arriba no lleva `listo` porque también
  // se usa como INPUT al guardar un pedido nuevo).
  static final Map<String, Map<String, List<bool>>> _listoCache = {};

  static void _cacheListos(String restaurantId, String mesaId, List items) {
    _listoCache.putIfAbsent(restaurantId, () => {})[mesaId] =
        items.map((e) => (e as Map<String, dynamic>)['listo'] as bool? ?? false).toList();
  }

  /// Guarda (o reemplaza) el pedido de una mesa. Si la lista de ítems queda
  /// vacía, elimina el pedido de esa mesa.
  static Future<void> guardarPedido(
    String restaurantId, {
    required String           mesaId,
    required int              mesaNumero,
    required int              orden,
    required List<ItemPedido> items,
  }) async {
    await ApiClient.put(
      '/restaurants/$restaurantId/pedidos/$mesaId',
      body: {
        'mesaNumero': mesaNumero,
        'orden':      orden,
        'items':      items.map((i) => i.toJson()).toList(),
      },
    );
  }

  /// Lista de pedidos activos (todas las mesas con pedido).
  static Future<List<PedidoActivo>> getPedidos(String restaurantId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/pedidos') as List;
    final result = <PedidoActivo>[];
    for (final e in json) {
      final m = e as Map<String, dynamic>;
      _cacheListos(restaurantId, m['id'] as String, m['items'] as List);
      result.add(PedidoActivo.fromJson(m));
    }
    return result;
  }

  /// Pedido de una mesa concreta (o null si no tiene).
  static Future<PedidoActivo?> getPedidoMesa(
      String restaurantId, String mesaId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/pedidos/$mesaId');
    if (json == null) return null;
    final m = json as Map<String, dynamic>;
    _cacheListos(restaurantId, mesaId, m['items'] as List);
    return PedidoActivo.fromJson(m);
  }

  static Future<void> eliminarPedido(
      String restaurantId, String mesaId) async {
    await ApiClient.delete('/restaurants/$restaurantId/pedidos/$mesaId');
    _listoCache[restaurantId]?.remove(mesaId);
  }

  // ── Estado "listo" de los ítems (despacho) ─────────────────────────────────

  /// Índices de ítems marcados como listos para una mesa.
  static Future<Set<int>> getListos(
      String restaurantId, String mesaId) async {
    var flags = _listoCache[restaurantId]?[mesaId];
    if (flags == null) {
      await getPedidoMesa(restaurantId, mesaId);
      flags = _listoCache[restaurantId]?[mesaId];
    }
    if (flags == null) return {};
    final result = <int>{};
    for (var i = 0; i < flags.length; i++) {
      if (flags[i]) result.add(i);
    }
    return result;
  }

  /// Marca/desmarca un ítem (por índice) como listo.
  static Future<void> setListo(
    String restaurantId,
    String mesaId,
    int    itemIndex, {
    required bool listo,
  }) async {
    final json = await ApiClient.patch(
      '/restaurants/$restaurantId/pedidos/$mesaId/items/$itemIndex/listo',
      body: {'listo': listo},
    ) as Map<String, dynamic>;
    _cacheListos(restaurantId, mesaId, json['items'] as List);
  }

  /// IDs de mesas "atendidas": tienen pedido y TODOS sus ítems están listos.
  static Future<Set<String>> getMesasAtendidas(String restaurantId) async {
    final json = await ApiClient.get(
      '/restaurants/$restaurantId/pedidos/mesas-atendidas',
    ) as List;
    return json.map((e) => e as String).toSet();
  }
}
