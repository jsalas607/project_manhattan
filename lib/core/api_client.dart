import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
import 'session.dart';

/// Cliente HTTP delgado sobre `package:http`: agrega la URL base, el header
/// `Authorization: Bearer <token>` cuando hay sesión, codifica/decodifica
/// JSON en UTF-8 y convierte respuestas de error en [ApiException].
class ApiClient {
  static final http.Client _client = http.Client();

  static Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  static Map<String, String> _headers({bool withBody = true}) {
    final h = <String, String>{};
    if (withBody) h['Content-Type'] = 'application/json; charset=utf-8';
    if (Session.token != null) {
      h['Authorization'] = 'Bearer ${Session.token}';
    }
    return h;
  }

  static dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    String detail = res.reasonPhrase ?? 'Error de red';
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['detail'] != null) {
        detail = body['detail'].toString();
      }
    } catch (_) {
      // cuerpo no era JSON; se usa reasonPhrase
    }
    throw ApiException(res.statusCode, detail);
  }

  static Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final res = await _client
        .get(_uri(path, query), headers: _headers(withBody: false));
    return _decode(res);
  }

  static Future<dynamic> post(String path, {Object? body, Map<String, String>? query}) async {
    final res = await _client.post(
      _uri(path, query),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  static Future<dynamic> put(String path, {Object? body}) async {
    final res = await _client.put(
      _uri(path),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  static Future<dynamic> patch(String path, {Object? body}) async {
    final res = await _client.patch(
      _uri(path),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  static Future<dynamic> delete(String path) async {
    final res = await _client.delete(_uri(path), headers: _headers(withBody: false));
    return _decode(res);
  }
}
