// API real para: profile_screen.dart

import '../../core/api_client.dart';

class UserProfile {
  final String id;
  final String username;
  final String title;
  final String name;
  final String lastname;
  final String description;
  final String role;

  const UserProfile({
    required this.id,
    required this.username,
    this.title = '',
    this.name = '',
    this.lastname = '',
    this.description = '',
    this.role = 'Administrador',
  });

  UserProfile copyWith({
    String? title,
    String? name,
    String? lastname,
    String? description,
  }) {
    return UserProfile(
      id: id,
      username: username,
      title: title ?? this.title,
      name: name ?? this.name,
      lastname: lastname ?? this.lastname,
      description: description ?? this.description,
      role: role,
    );
  }

  static UserProfile fromJson(Map<String, dynamic> j) => UserProfile(
        id:          j['id'] as String,
        username:    j['username'] as String,
        title:       j['title'] as String? ?? '',
        name:        j['name'] as String? ?? '',
        lastname:    j['lastname'] as String? ?? '',
        description: j['description'] as String? ?? '',
        role:        j['role'] as String? ?? '',
      );
}

class MockProfileApi {
  static Future<UserProfile> get() async {
    final json = await ApiClient.get('/profile') as Map<String, dynamic>;
    return UserProfile.fromJson(json);
  }

  static Future<UserProfile> update(UserProfile data) async {
    final json = await ApiClient.put('/profile', body: {
      'title':       data.title,
      'name':        data.name,
      'lastname':    data.lastname,
      'description': data.description,
    }) as Map<String, dynamic>;
    return UserProfile.fromJson(json);
  }
}
