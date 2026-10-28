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

  AuthStatus get status => _status;
  AccountInfo? get account => _account;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

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
