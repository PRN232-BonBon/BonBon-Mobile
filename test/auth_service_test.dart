import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bonbon_mobile/models/auth.dart';
import 'package:bonbon_mobile/services/auth_api.dart';
import 'package:bonbon_mobile/services/token_store.dart';

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.session]);

  StoredSession? session;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> write(StoredSession value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

const _account = AccountInfo(
  accountId: 'acc-1',
  email: 'an@example.com',
  fullName: 'Nguyễn Văn An',
  roles: ['Customer'],
);

const _session = StoredSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  account: _account,
);

void main() {
  test('login gửi đúng endpoint và parse AuthResponse', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'accessToken': 'new-access',
          'refreshToken': 'new-refresh',
          'accessTokenExpiresAt': 1700000000,
          'account': _account.toJson(),
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = AuthService(
      client: client,
      tokenStore: MemoryTokenStore(),
      baseUrl: 'http://localhost:5188/api/',
    );

    final result = await service.login(
      const LoginRequest(
        email: 'an@example.com',
        password: 'matkhau123',
        deviceInfo: 'BonBon Mobile',
      ),
    );

    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'http://localhost:5188/api/auth/login');
    expect(jsonDecode(captured.body), {
      'email': 'an@example.com',
      'password': 'matkhau123',
      'deviceInfo': 'BonBon Mobile',
    });
    expect(result.accessToken, 'new-access');
    expect(result.refreshToken, 'new-refresh');
    expect(result.account.fullName, 'Nguyễn Văn An');
  });

  test('lỗi ProblemDetails được đổi thành ApiException', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'title': 'Unauthorized',
          'detail': 'Sai email hoặc mật khẩu.',
          'status': 401,
        }),
        401,
        headers: {'content-type': 'application/problem+json; charset=utf-8'},
      ),
    );

    final service = AuthService(
      client: client,
      tokenStore: MemoryTokenStore(),
      baseUrl: 'http://localhost:5188/api',
    );

    expect(
      () => service.login(
        const LoginRequest(email: 'an@example.com', password: 'sai'),
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 401)
            .having((e) => e.message, 'message', 'Sai email hoặc mật khẩu.'),
      ),
    );
  });

  test('mất kết nối được báo là lỗi kết nối', () async {
    final client = MockClient((_) async => throw http.ClientException('boom'));

    final service = AuthService(
      client: client,
      tokenStore: MemoryTokenStore(),
      baseUrl: 'http://localhost:5188/api',
    );

    expect(
      () => service.login(
        const LoginRequest(email: 'an@example.com', password: 'matkhau123'),
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 0)
            .having((e) => e.title, 'title', 'Lỗi kết nối'),
      ),
    );
  });

  test('logout-all gắn Bearer token từ phiên đã lưu', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('', 204);
    });

    final service = AuthService(
      client: client,
      tokenStore: MemoryTokenStore(_session),
      baseUrl: 'http://localhost:5188/api',
    );

    await service.logoutAll();

    expect(
      captured.url.toString(),
      'http://localhost:5188/api/auth/logout-all',
    );
    expect(captured.headers['Authorization'], 'Bearer access-token');
  });

  test('đổi mật khẩu gọi /auth/change-password với token hiện tại', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('', 204);
    });

    final service = AuthService(
      client: client,
      tokenStore: MemoryTokenStore(_session),
      baseUrl: 'http://localhost:5188/api',
    );

    await service.changePassword(
      currentPassword: 'matkhau123',
      newPassword: 'matkhaumoi456',
    );

    expect(
      captured.url.toString(),
      'http://localhost:5188/api/auth/change-password',
    );
    expect(captured.method, 'POST');
    expect(captured.headers['Authorization'], 'Bearer access-token');
    expect(jsonDecode(captured.body), {
      'currentPassword': 'matkhau123',
      'newPassword': 'matkhaumoi456',
    });
  });
}
