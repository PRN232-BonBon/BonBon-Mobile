import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/auth.dart';
import '../services/auth_api.dart';
import '../services/token_store.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

/// Tương đương `AuthContext` bên web: giữ phiên đăng nhập và các thao tác auth.
class AuthController extends ChangeNotifier {
  AuthController({required this.api, required this.tokenStore});

  final AuthApi api;
  final TokenStore tokenStore;

  AuthStatus _status = AuthStatus.loading;
  AccountInfo? _account;
  String? _accessToken;
  String? _refreshToken;
  bool _disposed = false;
  Future<bool>? _refreshing;

  AuthStatus get status => _status;
  AccountInfo? get account => _account;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Hạn của access token, đọc từ claim `exp` trong JWT.
  DateTime? get accessTokenExpiresAt => _jwtExpiry(_accessToken);

  /// Đọc lại phiên đã lưu khi app khởi động.
  Future<void> hydrate() async {
    final session = await tokenStore.read();
    if (session == null) {
      _status = AuthStatus.unauthenticated;
    } else {
      _apply(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        account: session.account,
      );
    }
    _notify();

    // Token hết hạn trong lúc app đóng thì làm mới trước khi dùng tracking.
    final expiry = accessTokenExpiresAt;
    if (expiry != null &&
        !expiry.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      unawaited(refreshSession());
    }
  }

  /// Trả access token còn hạn, tự refresh nếu sắp hết hạn.
  Future<String?> validAccessToken({
    Duration leeway = const Duration(minutes: 2),
  }) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) return null;

    final expiry = _jwtExpiry(token);
    if (expiry == null || expiry.isAfter(DateTime.now().add(leeway))) {
      return token;
    }

    final refreshed = await refreshSession();
    return refreshed ? _accessToken : token;
  }

  /// Dùng refresh token để lấy access token mới. Chỉ một request refresh
  /// chạy tại một thời điểm vì backend rotate refresh token.
  Future<bool> refreshSession() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;

    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return Future.value(false);
    }

    final future = _refresh(refreshToken);
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
  }

  Future<bool> _refresh(String refreshToken) async {
    try {
      final response = await api.refresh(refreshToken);
      // Đăng xuất/đăng nhập tài khoản khác trong lúc chờ thì bỏ kết quả cũ.
      if (_refreshToken != refreshToken) return false;
      if (response.accessToken.isEmpty) return false;
      _applyResponse(response);
      await _persist();
      _notify();
      return true;
    } catch (_) {
      return false;
    }
  }

  static DateTime? _jwtExpiry(String? token) {
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return null;
      final exp = payload['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    } catch (_) {
      return null;
    }
  }

  /// Đổi mật khẩu của tài khoản đang đăng nhập (`/api/auth/change-password`).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => api.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  /// Chạy một request cần Bearer token, tự refresh một lần khi gặp 401.
  Future<T> authorized<T>(Future<T> Function(String accessToken) run) async {
    final token = await validAccessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        title: 'UNAUTHENTICATED',
        detail: 'Phiên đăng nhập không còn hiệu lực.',
        status: 401,
      );
    }

    try {
      return await run(token);
    } on ApiException catch (error) {
      if (error.status != 401) rethrow;
      if (!await refreshSession()) rethrow;
      final refreshed = _accessToken;
      if (refreshed == null || refreshed.isEmpty) rethrow;
      return run(refreshed);
    }
  }

  Future<void> login(LoginRequest body) async {
    _applyResponse(await api.login(body));
    await _persist();
    _notify();
  }

  Future<void> register(RegisterRequest body) async {
    _applyResponse(await api.register(body));
    await _persist();
    _notify();
  }

  Future<void> googleLogin(String idToken) async {
    _applyResponse(await api.googleLogin(idToken));
    await _persist();
    _notify();
  }

  Future<void> logout() async {
    final refreshToken = _refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await api.logout(refreshToken);
      } catch (_) {
        // Token có thể đã hết hạn — vẫn xoá phiên như bản web.
      }
    }
    await _clear();
  }

  Future<void> logoutAll() async {
    try {
      await api.logoutAll();
    } catch (_) {
      // Bỏ qua lỗi, vẫn đăng xuất trên thiết bị.
    }
    await _clear();
  }

  void _applyResponse(AuthResponse response) => _apply(
    accessToken: response.accessToken,
    refreshToken: response.refreshToken,
    account: response.account,
  );

  void _apply({
    required String accessToken,
    required String refreshToken,
    required AccountInfo account,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _account = account;
    _status = AuthStatus.authenticated;
  }

  Future<void> _persist() async {
    await tokenStore.write(
      StoredSession(
        accessToken: _accessToken ?? '',
        refreshToken: _refreshToken ?? '',
        account: _account!,
      ),
    );
  }

  Future<void> _clear() async {
    _accessToken = null;
    _refreshToken = null;
    _account = null;
    _status = AuthStatus.unauthenticated;
    await tokenStore.clear();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
