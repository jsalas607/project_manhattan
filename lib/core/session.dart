import 'package:shared_preferences/shared_preferences.dart';

/// Sesión: token JWT + id de usuario actual.
/// Se guarda en disco (SharedPreferences) para no pedir login en cada
/// apertura de la app.
class Session {
  static String? token;
  static String? userId;

  static bool get isLoggedIn => token != null;

  static Future<void> save(String token, String userId) async {
    Session.token = token;
    Session.userId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('auth_user_id', userId);
  }

  /// Intenta restaurar la sesión guardada. Devuelve true si había una.
  static Future<bool> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('auth_token');
    if (t == null) return false;
    token = t;
    userId = prefs.getString('auth_user_id');
    return true;
  }

  static Future<void> clear() async {
    token = null;
    userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user_id');
  }
}
