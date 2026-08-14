/// Configuración de conexión al backend real.
///
/// El backend vive en un servidor propio con dominio fijo — ya no se usa
/// el túnel de Cloudflare, así que esta URL no cambia entre sesiones.
/// Health check: https://api.manhattan-project.online/health
class ApiConfig {
  /// Host del backend, SIN esquema (http/https) ni barra final.
  static const String host = 'api.manhattan-project.online';

  static const String baseUrl = 'https://$host/api';
  static const String wsBaseUrl = 'wss://$host/ws';
}
