// API real para: cartera_screen.dart

import '../../core/api_client.dart';

enum CajaStatus { abierta, cerrada }

CajaStatus _cajaStatusFromString(String s) =>
    s == 'abierta' ? CajaStatus.abierta : CajaStatus.cerrada;

class CajaState {
  final CajaStatus status;
  final DateTime? abiertaEn;
  final Map<String, double> montosIniciales;

  const CajaState({
    required this.status,
    this.abiertaEn,
    this.montosIniciales = const {},
  });

  double get montoTotal =>
      montosIniciales.values.fold(0, (sum, v) => sum + v);

  static CajaState fromJson(Map<String, dynamic> j) => CajaState(
        status: _cajaStatusFromString(j['status'] as String),
        abiertaEn: j['abiertaEn'] == null
            ? null
            : DateTime.parse(j['abiertaEn'] as String).toLocal(),
        montosIniciales: (j['montosIniciales'] as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      );
}

class PaymentMethodTotal {
  final String name;
  final double total;

  const PaymentMethodTotal({required this.name, required this.total});

  static PaymentMethodTotal fromJson(Map<String, dynamic> j) => PaymentMethodTotal(
        name:  j['name'] as String,
        total: (j['total'] as num).toDouble(),
      );
}

class DailyStats {
  final int ordenesCreadias;
  final double dineroFacturado;
  final double promedioOrden;
  final double gastosDia;
  final double perdidasDia;

  const DailyStats({
    required this.ordenesCreadias,
    required this.dineroFacturado,
    required this.promedioOrden,
    required this.gastosDia,
    required this.perdidasDia,
  });

  static DailyStats fromJson(Map<String, dynamic> j) => DailyStats(
        ordenesCreadias: j['ordenesCreadias'] as int,
        dineroFacturado: (j['dineroFacturado'] as num).toDouble(),
        promedioOrden:   (j['promedioOrden'] as num).toDouble(),
        gastosDia:       (j['gastosDia'] as num).toDouble(),
        perdidasDia:     (j['perdidasDia'] as num).toDouble(),
      );
}

class GastoProducto {
  final String name;
  final String unidad;
  final double cantidad;

  const GastoProducto({
    required this.name,
    required this.unidad,
    required this.cantidad,
  });

  static GastoProducto fromJson(Map<String, dynamic> j) => GastoProducto(
        name:     j['name'] as String,
        unidad:   j['unidad'] as String? ?? 'und',
        cantidad: (j['cantidad'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'name': name, 'unidad': unidad, 'cantidad': cantidad};
}

class Gasto {
  final String id;
  final String descripcion;
  final double monto;
  final DateTime fecha;
  final String metodoPago;
  final List<GastoProducto> productos;

  const Gasto({
    required this.id,
    required this.descripcion,
    required this.monto,
    required this.fecha,
    this.metodoPago = 'efectivo',
    this.productos = const [],
  });

  static Gasto fromJson(Map<String, dynamic> j) => Gasto(
        id:          j['id'] as String,
        descripcion: j['descripcion'] as String,
        monto:       (j['monto'] as num).toDouble(),
        fecha:       DateTime.parse(j['fecha'] as String).toLocal(),
        metodoPago:  j['metodoPago'] as String? ?? 'efectivo',
        productos: (j['productos'] as List? ?? const [])
            .map((e) => GastoProducto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PerdidaProducto {
  final String name;
  final double cantidad;
  final String? unidad;
  final String? itemId; // id en inventario si vino del catálogo

  const PerdidaProducto({
    required this.name,
    required this.cantidad,
    this.unidad,
    this.itemId,
  });

  static PerdidaProducto fromJson(Map<String, dynamic> j) => PerdidaProducto(
        name:     j['name'] as String,
        cantidad: (j['cantidad'] as num?)?.toDouble() ?? 0,
        unidad:   j['unidad'] as String?,
        itemId:   j['itemId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name':     name,
        'cantidad': cantidad,
        'unidad':   unidad,
        'itemId':   itemId,
      };
}

class Perdida {
  final String id;
  final String titulo;
  final String descripcion;
  final String categoria;     // ventas | cocina | almacén | caducidad | otro
  final List<PerdidaProducto> productos;
  final DateTime fecha;

  const Perdida({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.categoria,
    required this.fecha,
    this.productos = const [],
  });

  /// Suma de cantidades — proxy de monto hasta que el catálogo tenga precios.
  double get monto =>
      productos.fold(0, (sum, p) => sum + p.cantidad);

  static Perdida fromJson(Map<String, dynamic> j) => Perdida(
        id:          j['id'] as String,
        titulo:      j['titulo'] as String,
        descripcion: j['descripcion'] as String? ?? '',
        categoria:   j['categoria'] as String? ?? 'otro',
        fecha:       DateTime.parse(j['fecha'] as String).toLocal(),
        productos: (j['productos'] as List? ?? const [])
            .map((e) => PerdidaProducto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MockCarteraApi {
  // -- Caja --

  static Future<CajaState> getCajaState(String restaurantId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/caja') as Map<String, dynamic>;
    return CajaState.fromJson(json);
  }

  static Future<CajaState> abrirCaja(
      String restaurantId, Map<String, double> montosIniciales) async {
    final json = await ApiClient.post(
      '/restaurants/$restaurantId/caja/abrir',
      body: {'montosIniciales': montosIniciales},
    ) as Map<String, dynamic>;
    return CajaState.fromJson(json);
  }

  static Future<CajaState> cerrarCaja(String restaurantId) async {
    final json =
        await ApiClient.post('/restaurants/$restaurantId/caja/cerrar') as Map<String, dynamic>;
    return CajaState.fromJson(json);
  }

  // -- Totales por método de pago --

  static Future<List<PaymentMethodTotal>> getTotalesPorMetodo(
      String restaurantId, List<String> metodos) async {
    final json = await ApiClient.get(
      '/restaurants/$restaurantId/caja/totales',
      query: {'metodos': metodos.join(',')},
    ) as List;
    return json.map((e) => PaymentMethodTotal.fromJson(e as Map<String, dynamic>)).toList();
  }

  // -- Estadísticas del día --

  static Future<DailyStats> getStats(String restaurantId) async {
    final json =
        await ApiClient.get('/restaurants/$restaurantId/stats') as Map<String, dynamic>;
    return DailyStats.fromJson(json);
  }

  // -- Gastos --

  static Future<List<Gasto>> getGastos(String restaurantId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/gastos') as List;
    return json.map((e) => Gasto.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Gasto> addGasto(
    String restaurantId,
    String descripcion,
    double monto, {
    String metodoPago = 'efectivo',
    List<GastoProducto> productos = const [],
  }) async {
    final json = await ApiClient.post(
      '/restaurants/$restaurantId/gastos',
      body: {
        'descripcion': descripcion,
        'monto':       monto,
        'metodoPago':  metodoPago,
        'productos':   productos.map((p) => p.toJson()).toList(),
      },
    ) as Map<String, dynamic>;
    return Gasto.fromJson(json);
  }

  // -- Pérdidas --

  static Future<List<Perdida>> getPerdidas(String restaurantId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/perdidas') as List;
    return json.map((e) => Perdida.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Perdida> addPerdida(
    String restaurantId, {
    required String titulo,
    required String descripcion,
    required String categoria,
    List<PerdidaProducto> productos = const [],
  }) async {
    final json = await ApiClient.post(
      '/restaurants/$restaurantId/perdidas',
      body: {
        'titulo':      titulo,
        'descripcion': descripcion,
        'categoria':   categoria,
        'productos':   productos.map((p) => p.toJson()).toList(),
      },
    ) as Map<String, dynamic>;
    return Perdida.fromJson(json);
  }
}
