import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth.dart';

/// Gửi request JSON tới backend và chuẩn hoá ProblemDetails thành [ApiException].
///
/// Dùng chung cho các endpoint ngoài auth/tracking để phần decode, gắn Bearer
/// token và đọc lỗi chỉ nằm ở một chỗ.
class JsonApiClient {
  JsonApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _baseUrl = _normalize(baseUrl ?? AppConfig.apiBaseUrl);

  final http.Client _client;
  final String _baseUrl;
  final bool _ownsClient;

  static String _normalize(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  Future<Object?> get(String path, {String? accessToken}) =>
      _send('GET', path, accessToken: accessToken);

  Future<Object?> post(
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) => _send('POST', path, body: body, accessToken: accessToken);

  Future<Object?> put(
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) => _send('PUT', path, body: body, accessToken: accessToken);

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };

    final http.Response response;
    try {
      final request = http.Request(method, Uri.parse('$_baseUrl$path'))
        ..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(
        await _client.send(request),
      ).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException(
        title: 'Hết thời gian chờ',
        detail: 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
      );
    } catch (_) {
      throw ApiException(
        title: 'Lỗi kết nối',
        detail: 'Không thể kết nối tới backend tại $_baseUrl. Kiểm tra backend đang chạy và địa chỉ API phù hợp với thiết bị.',
        status: 0,
      );
    }

    return _decode(response);
  }

  Object? _decode(http.Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

    Object? decoded;
    if (response.bodyBytes.isNotEmpty) {
      try {
        decoded = jsonDecode(
          utf8.decode(response.bodyBytes, allowMalformed: true),
        );
      } on FormatException {
        decoded = null;
      }
    }

    if (isSuccess) return decoded;

    final problem = decoded is Map ? decoded.cast<String, dynamic>() : null;
    final title = (problem?['title'] as String?)?.trim();
    throw ApiException(
      title: title == null || title.isEmpty ? 'Đã xảy ra lỗi' : title,
      detail:
          _validationMessage(problem) ??
          _nonEmpty(problem?['detail']) ??
          'Máy chủ trả về mã ${response.statusCode}.',
      status: (problem?['status'] as num?)?.toInt() ?? response.statusCode,
    );
  }

  static String? _validationMessage(Map<String, dynamic>? problem) {
    final errors = problem?['errors'];
    if (errors is! Map) return null;
    for (final value in errors.values) {
      if (value is! List) continue;
      for (final item in value) {
        final text = _nonEmpty(item);
        if (text != null) return text;
      }
    }
    return null;
  }

  static String? _nonEmpty(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
