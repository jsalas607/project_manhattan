// API real para: restaurant_list_screen.dart / create_restaurant_screen.dart

import '../../core/api_client.dart';
import '../../core/api_exception.dart';

class Restaurant {
  final String id;
  final String title;
  final String name;
  final String description;
  final String country;
  final String city;
  final String address;
  final List<String> paymentMethods;
  final bool isActive;

  const Restaurant({
    required this.id,
    required this.title,
    this.name = '',
    this.description = '',
    this.country = '',
    this.city = '',
    this.address = '',
    this.paymentMethods = const [],
    this.isActive = true,
  });

  Restaurant copyWith({
    String? id,
    String? title,
    String? name,
    String? description,
    String? country,
    String? city,
    String? address,
    List<String>? paymentMethods,
    bool? isActive,
  }) {
    return Restaurant(
      id: id ?? this.id,
      title: title ?? this.title,
      name: name ?? this.name,
      description: description ?? this.description,
      country: country ?? this.country,
      city: city ?? this.city,
      address: address ?? this.address,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      isActive: isActive ?? this.isActive,
    );
  }

  static Restaurant fromJson(Map<String, dynamic> j) => Restaurant(
        id:             j['id'] as String,
        title:          j['title'] as String,
        name:           j['name'] as String? ?? '',
        description:    j['description'] as String? ?? '',
        country:        j['country'] as String? ?? '',
        city:           j['city'] as String? ?? '',
        address:        j['address'] as String? ?? '',
        paymentMethods: List<String>.from(j['paymentMethods'] as List? ?? const []),
        isActive:       j['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'title':          title,
        'name':           name,
        'description':    description,
        'country':        country,
        'city':           city,
        'address':        address,
        'paymentMethods': paymentMethods,
        'isActive':       isActive,
      };
}

class MockRestaurantApi {
  static Future<List<Restaurant>> getAll() async {
    final json = await ApiClient.get('/restaurants') as List;
    return json.map((e) => Restaurant.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Busca un restaurante por id (para usuarios asignados a uno solo).
  static Future<Restaurant?> getById(String id) async {
    try {
      final json = await ApiClient.get('/restaurants/$id') as Map<String, dynamic>;
      return Restaurant.fromJson(json);
    } on ApiException catch (e) {
      if (e.isNotFound || e.isForbidden) return null;
      rethrow;
    }
  }

  static Future<Restaurant> create(Restaurant data) async {
    final json = await ApiClient.post('/restaurants', body: data.toJson())
        as Map<String, dynamic>;
    return Restaurant.fromJson(json);
  }

  static Future<Restaurant> update(Restaurant data) async {
    final json = await ApiClient.put('/restaurants/${data.id}', body: data.toJson())
        as Map<String, dynamic>;
    return Restaurant.fromJson(json);
  }

  static Future<Restaurant> duplicate(String id) async {
    final json = await ApiClient.post('/restaurants/$id/duplicate') as Map<String, dynamic>;
    return Restaurant.fromJson(json);
  }

  static Future<void> delete(String id) async {
    await ApiClient.delete('/restaurants/$id');
  }
}
