import 'dart:convert';

import 'package:eyesonly/services/api_exception.dart';

class ApiServiceSupport {
  ApiServiceSupport._();

  static Uri buildUri({
    required String baseUrl,
    required String path,
  }) {
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    final String normalizedBaseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$normalizedBaseUrl$normalizedPath');
  }

  static Map<String, String> jsonHeaders({
    String? authorization,
    Map<String, String>? extraHeaders,
  }) {
    return <String, String>{
      'Content-Type': 'application/json',
      if (authorization != null && authorization.trim().isNotEmpty)
        'Authorization': authorization.trim(),
      ...?extraHeaders,
    };
  }

  static Map<String, dynamic> decodeObject(String body) {
    final dynamic decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException('Expected a JSON object response', responseBody: body);
  }

  static List<dynamic> decodeList(String body) {
    final dynamic decoded = jsonDecode(body);
    if (decoded is List<dynamic>) {
      return decoded;
    }
    throw ApiException('Expected a JSON list response', responseBody: body);
  }

  static dynamic tryDecodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}