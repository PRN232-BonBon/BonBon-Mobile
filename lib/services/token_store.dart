import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth.dart';

/// Phiên đăng nhập được lưu lại giữa các lần mở app.
class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.refreshToken,
    required this.account,
  });

  final String accessToken;
  final String refreshToken;
  final AccountInfo account;
}

/// Tương đương `localStorage` bên frontend web.
abstract interface class TokenStore {
  Future<StoredSession?> read();

  Future<void> write(StoredSession session);

  Future<void> clear();
}

/// Lưu token bằng SharedPreferences (giữ nguyên key `bb_*` như bản web).
class SharedPrefsTokenStore implements TokenStore {
  static const String keyAccess = 'bb_access';
  static const String keyRefresh = 'bb_refresh';
  static const String keyAccount = 'bb_account';

  @override
  Future<StoredSession?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(keyAccess);
    final refreshToken = prefs.getString(keyRefresh);
    final rawAccount = prefs.getString(keyAccount);

    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        rawAccount == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawAccount);
      if (decoded is! Map) return null;
      return StoredSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        account: AccountInfo.fromJson(decoded.cast<String, dynamic>()),
      );
    } on FormatException {
      // Dữ liệu hỏng thì coi như chưa đăng nhập, giống bản web.
      return null;
    }
  }

  @override
  Future<void> write(StoredSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyAccess, session.accessToken);
    await prefs.setString(keyRefresh, session.refreshToken);
    await prefs.setString(keyAccount, jsonEncode(session.account.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyAccess);
    await prefs.remove(keyRefresh);
    await prefs.remove(keyAccount);
  }
}
