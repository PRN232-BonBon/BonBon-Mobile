import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonbon_mobile/models/auth.dart';
import 'package:bonbon_mobile/services/auth_api.dart';
import 'package:bonbon_mobile/services/token_store.dart';
import 'package:bonbon_mobile/state/auth_controller.dart';
import 'package:bonbon_mobile/state/auth_scope.dart';
import 'package:bonbon_mobile/tracking/tracking_api.dart';
import 'package:bonbon_mobile/tracking/tracking_map_page.dart';
import 'package:bonbon_mobile/tracking/tracking_models.dart';
import 'package:bonbon_mobile/tracking/tracking_trips_page.dart';

const _account = AccountInfo(
  accountId: 'acc-1',
  email: 'an@example.com',
  fullName: 'Nguyễn Văn An',
  roles: ['Customer'],
);

const _session = AuthResponse(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  accessTokenExpiresAt: 0,
  account: _account,
);

class _FakeAuthApi implements AuthApi {
  @override
  Future<AuthResponse> login(LoginRequest body) async => _session;

  @override
  Future<AuthResponse> register(RegisterRequest body) async => _session;

  @override
  Future<AuthResponse> googleLogin(String idToken) async => _session;

  @override
  Future<AuthResponse> refresh(String refreshToken) async => _session;

  @override
  Future<void> logout(String refreshToken) async {}

  @override
  Future<void> logoutAll() async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore([this.session]);

  StoredSession? session;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> write(StoredSession value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

class _BlockedTrackingApi implements TrackingApi {
  @override
  Future<List<OwnerBooking>> getOwnerBookings(String accessToken) async => [];

  @override
  Future<void> reportPosition(String bookingId, String accessToken, {required double latitude, required double longitude, double? accuracyMeters, DateTime? recordedAt}) async {}

  @override
  Future<List<CustomerBooking>> getMyBookings(String accessToken) async => [];

  @override
  Future<TrackingSnapshot> getSnapshot(
    String bookingId,
    String accessToken,
  ) async => throw const TrackingApiException(
    statusCode: 409,
    code: 'TRACKING_NOT_ACTIVE',
    message: 'Chưa tới giai đoạn theo dõi.',
  );

  @override
  Future<TrackingStatus> getStatus(String bookingId, String accessToken) async =>
      throw const TrackingApiException(
        statusCode: 409,
        code: 'TRACKING_NOT_ACTIVE',
        message: 'Chưa tới giai đoạn theo dõi.',
      );
}

class _FakeTrackingApi implements TrackingApi {
  _FakeTrackingApi({this.status = 'ReadyForPickup'});

  final String status;

  @override
  Future<List<OwnerBooking>> getOwnerBookings(String accessToken) async => [];

  @override
  Future<void> reportPosition(String bookingId, String accessToken, {required double latitude, required double longitude, double? accuracyMeters, DateTime? recordedAt}) async {}

  @override
  Future<List<CustomerBooking>> getMyBookings(String accessToken) async => [
    CustomerBooking.fromJson({
      'bookingId': '4f4c1f9e-8b0a-4f7b-9c3d-2a1b3c4d5e6f',
      'vehicleName': 'Toyota Vios',
      'plateNumber': '51A-123.45',
      'rentalType': 'Daily',
      'startAt': '2026-10-30T01:00:00Z',
      'endAt': '2026-10-31T01:00:00Z',
      'totalAmount': 900000,
      'currency': 'VND',
      'status': status,
      'createdAt': '2026-10-29T01:00:00Z',
    }),
  ];

  @override
  Future<TrackingSnapshot> getSnapshot(
    String bookingId,
    String accessToken,
  ) async => throw const TrackingApiException(
    statusCode: 503,
    code: 'POSITION_NOT_AVAILABLE',
    message: 'Chưa có vị trí.',
  );

  @override
  Future<TrackingStatus> getStatus(String bookingId, String accessToken) async =>
      throw const TrackingApiException(
        statusCode: 503,
        code: 'POSITION_NOT_AVAILABLE',
        message: 'Chưa có vị trí.',
      );
}

Future<AuthController> _controller({bool signedIn = true}) async {
  final controller = AuthController(
    api: _FakeAuthApi(),
    tokenStore: _MemoryTokenStore(
      signedIn
          ? const StoredSession(
              accessToken: 'access-token',
              refreshToken: 'refresh-token',
              account: _account,
            )
          : null,
    ),
  );
  await controller.hydrate();
  return controller;
}

Widget _wrap(AuthController controller, Widget home) {
  return AuthScope(
    controller: controller,
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets('bản đồ tracking bắt buộc đăng nhập', (tester) async {
    final controller = await _controller(signedIn: false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        controller,
        const TrackingMapPage(
          target: TrackingTarget(
            bookingId: '4f4c1f9e-8b0a-4f7b-9c3d-2a1b3c4d5e6f',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bạn cần đăng nhập'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Đăng nhập để xem bản đồ'),
      findsOneWidget,
    );
    expect(find.textContaining('xác định bạn là'), findsOneWidget);
  });

  testWidgets('đã đăng nhập nhưng sai giai đoạn thì báo lý do, không mở map', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        controller,
        TrackingMapPage(
          target: const TrackingTarget(
            bookingId: '4f4c1f9e-8b0a-4f7b-9c3d-2a1b3c4d5e6f',
          ),
          api: _BlockedTrackingApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa xem được vị trí'), findsOneWidget);
    expect(find.textContaining('giai đoạn theo dõi'), findsOneWidget);
    expect(find.text('Mã booking: 4F4C1F9E'), findsOneWidget);
    expect(find.text('Tài khoản: an@example.com'), findsOneWidget);
    expect(find.text('Bản đồ theo dõi'), findsOneWidget);
  });

  testWidgets('danh sách chuyến bắt buộc đăng nhập', (tester) async {
    final controller = await _controller(signedIn: false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(controller, TrackingTripsPage(api: _FakeTrackingApi())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bạn cần đăng nhập'), findsOneWidget);
    expect(find.text('Chuyến thuê của bạn'), findsNothing);
  });

  testWidgets('đã đăng nhập thì hiện chuyến và nút mở bản đồ', (tester) async {
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(controller, TrackingTripsPage(api: _FakeTrackingApi())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bạn cần đăng nhập'), findsNothing);
    expect(find.textContaining('an@example.com'), findsWidgets);
    expect(find.text('Toyota Vios'), findsOneWidget);
    expect(find.text('51A-123.45'), findsOneWidget);
    expect(find.text('CHUYẾN THUÊ CỦA BẠN'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.widgetWithText(ElevatedButton, 'Theo dõi xe tới điểm lấy'),
      200,
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(ElevatedButton, 'Theo dõi xe tới điểm lấy'),
      findsOneWidget,
    );
  });

  testWidgets('chuyến InProgress không còn nút theo dõi pickup', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        controller,
        TrackingTripsPage(api: _FakeTrackingApi(status: 'InProgress')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Toyota Vios'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Theo dõi xe tới điểm lấy'),
      findsNothing,
    );
    expect(find.textContaining('Chủ xe canh vị trí trả xe'), findsOneWidget);
  });
}
