import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonbon_mobile/app.dart';
import 'package:bonbon_mobile/models/auth.dart';
import 'package:bonbon_mobile/services/auth_api.dart';
import 'package:bonbon_mobile/services/token_store.dart';
import 'package:bonbon_mobile/state/auth_controller.dart';

const _account = AccountInfo(
  accountId: 'acc-1',
  email: 'an@example.com',
  fullName: 'Nguyễn Văn An',
  displayName: 'an',
  roles: ['Customer'],
);

const _session = AuthResponse(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  accessTokenExpiresAt: 0,
  account: _account,
);

class FakeAuthApi implements AuthApi {
  FakeAuthApi({this.error});

  final ApiException? error;
  final List<LoginRequest> logins = [];
  final List<RegisterRequest> registrations = [];

  @override
  Future<AuthResponse> login(LoginRequest body) async {
    logins.add(body);
    if (error != null) throw error!;
    return _session;
  }

  @override
  Future<AuthResponse> register(RegisterRequest body) async {
    registrations.add(body);
    if (error != null) throw error!;
    return _session;
  }

  @override
  Future<AuthResponse> googleLogin(String idToken) async => _session;

  @override
  Future<AuthResponse> refresh(String refreshToken) async => _session;

  @override
  Future<void> logout(String refreshToken) async {}

  @override
  Future<void> logoutAll() async {}
}

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.session]);

  StoredSession? session;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> write(StoredSession value) async {
    session = value;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

AuthController buildController({
  AuthApi? api,
  TokenStore? tokenStore,
}) =>
    AuthController(
      api: api ?? FakeAuthApi(),
      tokenStore: tokenStore ?? MemoryTokenStore(),
    );

void main() {
  testWidgets('màn hình đăng nhập hiện khi chưa có phiên', (tester) async {
    final controller = buildController();
    addTearDown(controller.dispose);
    await controller.hydrate();

    await tester.pumpWidget(BonBonApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'Đăng nhập'), findsOneWidget);
    expect(find.text('Chưa có tài khoản?'), findsOneWidget);
  });

  testWidgets('bỏ trống email/mật khẩu thì báo lỗi, không gọi API',
      (tester) async {
    final api = FakeAuthApi();
    final controller = buildController(api: api);
    addTearDown(controller.dispose);
    await controller.hydrate();

    await tester.pumpWidget(BonBonApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập email.'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget);
    expect(api.logins, isEmpty);
  });

  testWidgets('đăng nhập thành công thì chuyển sang Dashboard', (tester) async {
    final api = FakeAuthApi();
    final store = MemoryTokenStore();
    final controller = buildController(api: api, tokenStore: store);
    addTearDown(controller.dispose);
    await controller.hydrate();

    await tester.pumpWidget(BonBonApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'you@example.com'),
      'an@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '••••••••'),
      'matkhau123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(api.logins.single.email, 'an@example.com');
    expect(api.logins.single.deviceInfo, startsWith('BonBon Mobile'));
    expect(store.session?.accessToken, 'access-token');
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('@an'), findsOneWidget);
    expect(find.text('an@example.com'), findsOneWidget);
    expect(find.text('CUSTOMER'), findsOneWidget);
  });

  testWidgets('hiển thị lỗi trả về từ API khi đăng nhập thất bại',
      (tester) async {
    final controller = buildController(
      api: FakeAuthApi(
        error: const ApiException(
          title: 'Unauthorized',
          detail: 'Sai email hoặc mật khẩu.',
          status: 401,
        ),
      ),
    );
    addTearDown(controller.dispose);
    await controller.hydrate();

    await tester.pumpWidget(BonBonApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'you@example.com'),
      'an@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '••••••••'),
      'sai-mat-khau',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('Sai email hoặc mật khẩu.'), findsOneWidget);
  });

  testWidgets('đăng ký: mật khẩu xác nhận không khớp thì báo lỗi',
      (tester) async {
    final api = FakeAuthApi();
    final controller = buildController(api: api);
    addTearDown(controller.dispose);
    await controller.hydrate();

    await tester.pumpWidget(BonBonApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đăng ký ngay'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nguyễn Văn A'),
      'Trần Thị B',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'you@example.com'),
      'b@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tối thiểu 6 ký tự'),
      'matkhau123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nhập lại mật khẩu'),
      'khac-nhau',
    );
    await tester.ensureVisible(
      find.widgetWithText(ElevatedButton, 'Đăng ký'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
    expect(api.registrations, isEmpty);
  });

  testWidgets('đăng ký thành công thì vào Dashboard và lưu phiên',
      (tester) async {
    final api = FakeAuthApi();
    final store = MemoryTokenStore();
    final controller = buildController(api: api, tokenStore: store);
    addTearDown(controller.dispose);
    await controller.hydrate();

    await tester.pumpWidget(BonBonApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đăng ký ngay'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nguyễn Văn A'),
      'Trần Thị B',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'you@example.com'),
      'b@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tối thiểu 6 ký tự'),
      'matkhau123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nhập lại mật khẩu'),
      'matkhau123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tuỳ chọn').first,
      'bee',
    );
    await tester.ensureVisible(
      find.widgetWithText(ElevatedButton, 'Đăng ký'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(api.registrations.single.email, 'b@example.com');
    expect(api.registrations.single.displayName, 'bee');
    expect(api.registrations.single.phone, isNull);
    expect(store.session?.refreshToken, 'refresh-token');
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
  });

  testWidgets('đăng xuất quay về màn hình đăng nhập và xoá phiên',
      (tester) async {
    final store = MemoryTokenStore(
      const StoredSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        account: _account,
      ),
    );
    final controller = buildController(tokenStore: store);
    addTearDown(controller.dispose);
    await controller.hydrate();

    await tester.pumpWidget(BonBonApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Văn An'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
    await tester.pumpAndSettle();

    expect(store.session, isNull);
    expect(find.text('Chưa có tài khoản?'), findsOneWidget);
    expect(find.text('Nguyễn Văn An'), findsNothing);
  });

  testWidgets('token dài được rút gọn và bấm Xem để hiện đầy đủ',
      (tester) async {
    const accessToken =
        'a-very-long-access-token-that-is-definitely-over-48-chars';
    final store = MemoryTokenStore(
      const StoredSession(
        accessToken: accessToken,
        refreshToken: 'refresh-token',
        account: _account,
      ),
    );
    final controller = buildController(tokenStore: store);
    addTearDown(controller.dispose);
    await controller.hydrate();

    await tester.pumpWidget(BonBonApp(controller: controller));
    await tester.pumpAndSettle();

    final collapsed = '${accessToken.substring(0, 48)}…';
    expect(find.text(collapsed), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Xem').first);
    await tester.pumpAndSettle();

    expect(find.text(accessToken), findsOneWidget);
  });
}
