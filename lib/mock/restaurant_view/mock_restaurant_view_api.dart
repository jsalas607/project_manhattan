// API real para: restaurant_view_screen.dart

import '../../core/api_client.dart';

enum RestaurantStatus { abierto, cerrado }

RestaurantStatus _statusFromString(String s) =>
    s == 'abierto' ? RestaurantStatus.abierto : RestaurantStatus.cerrado;

String _statusToString(RestaurantStatus s) =>
    s == RestaurantStatus.abierto ? 'abierto' : 'cerrado';

class RestaurantViewData {
  final String restaurantId;
  final RestaurantStatus status;

  const RestaurantViewData({
    required this.restaurantId,
    required this.status,
  });

  RestaurantViewData copyWith({RestaurantStatus? status}) {
    return RestaurantViewData(
      restaurantId: restaurantId,
      status: status ?? this.status,
    );
  }
}

class MockRestaurantViewApi {
  static Future<RestaurantViewData> get(String restaurantId) async {
    final json = await ApiClient.get('/restaurants/$restaurantId/status')
        as Map<String, dynamic>;
    return RestaurantViewData(
      restaurantId: json['restaurantId'] as String,
      status: _statusFromString(json['status'] as String),
    );
  }

  static Future<RestaurantViewData> updateStatus(
    String restaurantId,
    RestaurantStatus status,
  ) async {
    final json = await ApiClient.put(
      '/restaurants/$restaurantId/status',
      body: {'status': _statusToString(status)},
    ) as Map<String, dynamic>;
    return RestaurantViewData(
      restaurantId: json['restaurantId'] as String,
      status: _statusFromString(json['status'] as String),
    );
  }
}
