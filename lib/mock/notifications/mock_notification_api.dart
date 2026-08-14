// API real para: notifications_screen.dart

import '../../core/api_client.dart';

enum NotificationType { info, advertencia, alerta }

enum NotificationStatus { leida, noLeida }

NotificationType _typeFromString(String s) {
  switch (s) {
    case 'advertencia': return NotificationType.advertencia;
    case 'alerta':       return NotificationType.alerta;
    default:             return NotificationType.info;
  }
}

NotificationStatus _statusFromString(String s) =>
    s == 'leida' ? NotificationStatus.leida : NotificationStatus.noLeida;

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  NotificationStatus status;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  static AppNotification fromJson(Map<String, dynamic> j) => AppNotification(
        id:        j['id'] as String,
        title:     j['title'] as String,
        message:   j['message'] as String,
        type:      _typeFromString(j['type'] as String),
        status:    _statusFromString(j['status'] as String),
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      );
}

class MockNotificationApi {
  static Future<List<AppNotification>> getAll() async {
    final json = await ApiClient.get('/notifications') as List;
    return json.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<int> unreadCount() async {
    final json = await ApiClient.get('/notifications/unread-count');
    return json as int;
  }

  static Future<void> markAsRead(String id) async {
    await ApiClient.patch('/notifications/$id/read');
  }

  static Future<void> markAllAsRead() async {
    await ApiClient.post('/notifications/read-all');
  }
}
