import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bonbon_mobile/models/auth.dart';
import 'package:bonbon_mobile/services/token_store.dart';

const _account = AccountInfo(
  accountId: 'acc-1',
  email: 'an@example.com',
  fullName: 'Nguyễn Văn An',
  displayName: 'an',
  roles: ['Customer'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('lưu, đọc lại và xoá phiên', () async {
    final store = SharedPrefsTokenStore();

    expect(await store.read(), isNull);

    await store.write(
      const StoredSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        account: _account,
      ),
    );

    final session = await store.read();
    expect(session?.accessToken, 'access-token');
    expect(session?.refreshToken, 'refresh-token');
    expect(session?.account.accountId, 'acc-1');
    expect(session?.account.fullName, 'Nguyễn Văn An');
    expect(session?.account.roles, ['Customer']);

    await store.clear();
    expect(await store.read(), isNull);
  });

  test('dữ liệu tài khoản hỏng thì coi như chưa đăng nhập', () async {
    SharedPreferences.setMockInitialValues({
      SharedPrefsTokenStore.keyAccess: 'access-token',
      SharedPrefsTokenStore.keyRefresh: 'refresh-token',
      SharedPrefsTokenStore.keyAccount: 'khong-phai-json',
    });

    expect(await SharedPrefsTokenStore().read(), isNull);
  });
}
