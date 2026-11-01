import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth.dart';
import 'token_store.dart';

/// Hợp đồng gọi backend, tách ra để test có thể thay bằng fake.
abstract interface class AuthApi {
  Future<AuthResponse> register(RegisterRequest body);

  Future<AuthResponse> login(LoginRequest body);

  Future<AuthResponse> googleLogin(String idToken);

  Future<AuthResponse> refresh(String refreshToken);

  Future<void> logout(String refreshToken);

  Future<void> logoutAll();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

/// Gọi các endpoint `/api/auth/*` giống `src/services/authService.ts`.
class AuthService implements AuthApi {
  AuthService({http.Client? client, required this.tokenStore, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = _normalize(baseUrl ?? AppConfig.apiBaseUrl);

  final http.Client _client;
  final TokenStore tokenStore;
  final String _baseUrl;

  static String _normalize(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  Uri _uri(String path) => Uri.parse('$_baseUrl/auth$path');

  @override
  Future<AuthResponse> register(RegisterRequest body) async {
    final json = await _send('POST', '/register', body: body.toJson());
    return AuthResponse.fromJson(json);
  }

  @override
  Future<AuthResponse> login(LoginRequest body) async {
    final json = await _send('POST', '/login', body: body.toJson());
    return AuthResponse.fromJson(json);
  }

  @override
  Future<AuthResponse> googleLogin(String idToken) async {
    final json = await _send(
      'POST',
      '/google-login',
      body: {'idToken': idToken},
    );
    return AuthResponse.fromJson(json);
  }

  @override
  Future<AuthResponse> refresh(String refreshToken) async {
    final json = await _send(
      'POST',
      '/refresh',
      body: {'refreshToken': refreshToken},
    );
    return AuthResponse.fromJson(json);
  }

  @override
  Future<void> logout(String refreshToken) async {
    await _send('POST', '/logout', body: {'refreshToken': refreshToken});
  }

  @override
  Future<void> logoutAll() async {
    await _send('POST', '/logout-all');
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _send(
      'POST',
      '/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  /// Gửi request, tự gắn Bearer token (tương đương axios interceptor).
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };

    final session = await tokenStore.read();
    final accessToken = session?.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final http.Response response;
    try {
      final request = http.Request(method, _uri(path))..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(await _client.send(request));
    } catch (_) {
      // Mất mạng, sai host, cert tự ký… đều quy về lỗi kết nối như bản web.
      throw ApiException(
        title: 'Lỗi kết nối',
        detail: 'Không thể kết nối tới backend tại $_baseUrl. Kiểm tra backend đang chạy và địa chỉ API phù hợp với thiết bị.',
        status: 0,
      );
    }

    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

    Map<String, dynamic>? data;
    if (response.bodyBytes.isNotEmpty) {
      try {
        // Luôn đọc UTF-8 để tiếng Việt không phụ thuộc header charset.
        final decoded = jsonDecode(
          utf8.decode(response.bodyBytes, allowMalformed: true),
        );
        if (decoded is Map) data = decoded.cast<String, dynamic>();
      } on FormatException {
        data = null;
      }
    }

    if (isSuccess) return data ?? const {};

    if (data != null) {
      throw ApiException(
        title: (data['title'] as String?)?.trim().isNotEmpty == true
            ? data['title'] as String
            : 'Đã xảy ra lỗi',
        detail: data['detail'] as String?,
        status: (data['status'] as num?)?.toInt() ?? response.statusCode,
      );
    }

    throw ApiException(
      title: 'Đã xảy ra lỗi',
      detail: 'Máy chủ trả về mã ${response.statusCode}.',
      status: response.statusCode,
    );
  }
}
