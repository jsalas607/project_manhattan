// API real para: inventory_screen.dart / add_gasto_screen.dart / add_perdida_screen.dart
//
// Lógica de inventario diario (la calcula el backend):
//   - Cada día se registra un conteo físico (invReal).
//   - El invApp del día siguiente = invReal del día anterior.
//   - diff = invReal - invApp → negativo indica posible pérdida o robo.

import '../../core/api_client.dart';

class InventoryItem {
  final String id;
  final String name;
  final String unidad;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.unidad,
  });

  static InventoryItem fromJson(Map<String, dynamic> j) => InventoryItem(
        id:     j['id'] as String,
        name:   j['name'] as String,
        unidad: j['unidad'] as String? ?? 'und',
      );
}

class DailyEntry {
  final String itemId;
  final double invApp;    // heredado del invReal del día anterior
  final double? invReal;  // null = aún no contado físicamente

  const DailyEntry({
    required this.itemId,
    required this.invApp,
    this.invReal,
  });

  bool get isCounted => invReal != null;
  double get diff => isCounted ? invReal! - invApp : 0;
  bool get hasDiff => isCounted && diff != 0;

  static DailyEntry fromJson(Map<String, dynamic> j) => DailyEntry(
        itemId:  j['itemId'] as String,
        invApp:  (j['invApp'] as num).toDouble(),
        invReal: j['invReal'] == null ? null : (j['invReal'] as num).toDouble(),
      );
}

class DailyInventoryRecord {
  final InventoryItem item;
  final DailyEntry entry;

  const DailyInventoryRecord({required this.item, required this.entry});

  static DailyInventoryRecord fromJson(Map<String, dynamic> j) => DailyInventoryRecord(
        item:  InventoryItem.fromJson(j['item'] as Map<String, dynamic>),
        entry: DailyEntry.fromJson(j['entry'] as Map<String, dynamic>),
      );
}

/// Inventario completo de un día: si está cerrado + sus registros.
class DayInventory {
  final bool closed;
  final List<DailyInventoryRecord> records;
  const DayInventory({required this.closed, required this.records});
}

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class MockInventoryApi {
  /// Catálogo de ingredientes del restaurante (derivado del inventario de hoy).
  static Future<List<InventoryItem>> getCatalog(String restaurantId) async {
    final day = await getByDate(restaurantId, DateTime.now());
    return day.records.map((r) => r.item).toList();
  }

  /// Fechas disponibles en el historial (últimos 7 días).
  static Future<List<DateTime>> availableDates(String restaurantId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/inventory/dates') as List;
    return json.map((s) {
      final parts = (s as String).split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }).toList();
  }

  /// Inventario de una fecha específica (incluye si el día está cerrado).
  static Future<DayInventory> getByDate(String restaurantId, DateTime date) async {
    final json = await ApiClient.get(
      '/restaurants/$restaurantId/inventory',
      query: {'date': _dateKey(date)},
    ) as Map<String, dynamic>;
    return DayInventory(
      closed: json['closed'] as bool? ?? false,
      records: (json['records'] as List)
          .map((e) => DailyInventoryRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Actualiza el invReal de un item en una fecha.
  static Future<void> updateInvReal(
      String restaurantId, DateTime date, String itemId, double invReal) async {
    await ApiClient.put(
      '/restaurants/$restaurantId/inventory/$itemId/real',
      body: {'date': _dateKey(date), 'invReal': invReal},
    );
  }

  /// Añade un nuevo ingrediente al catálogo y lo registra en el día de hoy
  /// con invReal = null (pendiente de conteo físico).
  static Future<InventoryItem> addItemToday(
    String restaurantId, {
    required String name,
    required String unidad,
  }) async {
    final json = await ApiClient.post(
      '/restaurants/$restaurantId/inventory/items',
      body: {'name': name, 'unidad': unidad},
    ) as Map<String, dynamic>;
    return InventoryItem.fromJson(json);
  }

  /// Registra una merma/pérdida: resta `cantidad` del invApp (y invReal si existe).
  static Future<void> registrarMerma(
      String restaurantId, DateTime date, String itemId, double cantidad) async {
    await ApiClient.post(
      '/restaurants/$restaurantId/inventory/merma',
      body: {'date': _dateKey(date), 'itemId': itemId, 'cantidad': cantidad},
    );
  }

  /// Registra una compra: suma `cantidad` al invApp de hoy del ítem.
  static Future<void> addCompra(
      String restaurantId, DateTime date, String itemId, double cantidad) async {
    await ApiClient.post(
      '/restaurants/$restaurantId/inventory/compra',
      body: {'date': _dateKey(date), 'itemId': itemId, 'cantidad': cantidad},
    );
  }

  /// Elimina un ingrediente del inventario (y su historial de conteos).
  /// No afecta el menú.
  static Future<void> deleteItem(String restaurantId, String itemId) async {
    await ApiClient.delete('/restaurants/$restaurantId/inventory/$itemId');
  }

  /// Cierra el inventario del día — ya no se puede editar.
  static Future<void> closeDayInventory(String restaurantId, DateTime date) async {
    await ApiClient.post(
      '/restaurants/$restaurantId/inventory/close',
      query: {'date': _dateKey(date)},
    );
  }
}
