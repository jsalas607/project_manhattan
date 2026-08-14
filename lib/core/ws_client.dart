import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_config.dart';
import 'session.dart';

/// Cliente WebSocket para los canales `pedidos` y `despacho` de un
/// restaurante. Reconecta manualmente no incluido: si se cae, el caller
/// puede simplemente refrescar por REST (los datos igual se ven al recargar).
class RestaurantWsClient {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  /// [canal] es `'pedidos'` o `'despacho'`.
  void connect({
    required String restaurantId,
    required String canal,
    required void Function(Map<String, dynamic> event) onMessage,
  }) {
    final uri = Uri.parse(
      '${ApiConfig.wsBaseUrl}/restaurants/$restaurantId/$canal?token=${Session.token}',
    );
    _channel = WebSocketChannel.connect(uri);
    _sub = _channel!.stream.listen(
      (data) {
        try {
          final decoded = jsonDecode(data as String) as Map<String, dynamic>;
          onMessage(decoded);
        } catch (_) {
          // mensaje no-JSON, se ignora
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void dispose() {
    _sub?.cancel();
    _channel?.sink.close();
  }
}
