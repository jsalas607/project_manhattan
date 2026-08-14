// API real: registro de ventas (órdenes cobradas).
// Lo escribe CobrarMesaScreen; el backend guarda TODAS las ventas por día.

import '../../core/api_client.dart';
import '../pedidos/mock_pedidos_api.dart'; // ItemPedido

// ---------------------------------------------------------------------------
// Modelos
// ---------------------------------------------------------------------------

class PagoMetodo {
  final String metodo;
  final double monto;
  const PagoMetodo({required this.metodo, required this.monto});

  static PagoMetodo fromJson(Map<String, dynamic> j) => PagoMetodo(
        metodo: j['metodo'] as String,
        monto:  (j['monto'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'metodo': metodo, 'monto': monto};
}

class Venta {
  final String           id;
  final int              mesaNumero;
  final int              orden;
  final String           nombreCliente;
  final List<ItemPedido> items;
  final List<PagoMetodo> pagos;
  final double           total;
  final DateTime         fecha;

  const Venta({
    required this.id,
    required this.mesaNumero,
    required this.orden,
    required this.nombreCliente,
    required this.items,
    required this.pagos,
    required this.total,
    required this.fecha,
  });

  /// Solo la fecha (sin hora), para agrupar por día.
  DateTime get dia => DateTime(fecha.year, fecha.month, fecha.day);

  static Venta fromJson(Map<String, dynamic> j) => Venta(
        id:            j['id'] as String,
        mesaNumero:    j['mesaNumero'] as int,
        orden:         j['orden'] as int,
        nombreCliente: j['nombreCliente'] as String? ?? '',
        items: (j['items'] as List)
            .map((e) => ItemPedido.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagos: (j['pagos'] as List)
            .map((e) => PagoMetodo.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (j['total'] as num).toDouble(),
        fecha: DateTime.parse(j['fecha'] as String).toLocal(),
      );
}

class MockVentasApi {
  /// Registra una orden cobrada.
  static Future<Venta> registrarVenta(
    String restaurantId, {
    required int              mesaNumero,
    required int              orden,
    required String           nombreCliente,
    required List<ItemPedido> items,
    required List<PagoMetodo> pagos,
    required double           total,
  }) async {
    final json = await ApiClient.post(
      '/restaurants/$restaurantId/ventas',
      body: {
        'mesaNumero':    mesaNumero,
        'orden':         orden,
        'nombreCliente': nombreCliente,
        'items':         items.map((i) => i.toJson()).toList(),
        'pagos':         pagos.map((p) => p.toJson()).toList(),
        'total':         total,
      },
    ) as Map<String, dynamic>;
    return Venta.fromJson(json);
  }

  /// Todas las ventas del restaurante (cualquier día), más recientes primero.
  static Future<List<Venta>> getVentas(String restaurantId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/ventas') as List;
    final lista = json.map((e) => Venta.fromJson(e as Map<String, dynamic>)).toList();
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  /// Ventas de un día específico (por defecto, hoy).
  static Future<List<Venta>> getVentasDia(
      String restaurantId, {DateTime? dia}) async {
    final d = dia ?? DateTime.now();
    final query = {
      'date': '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}',
    };
    final json = await ApiClient.get(
      '/restaurants/$restaurantId/ventas/dia',
      query: query,
    ) as List;
    final lista = json.map((e) => Venta.fromJson(e as Map<String, dynamic>)).toList();
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }
}
