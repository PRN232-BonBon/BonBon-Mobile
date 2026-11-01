import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bonbon_mobile/tracking/tracking_api.dart';
import 'package:bonbon_mobile/tracking/tracking_models.dart';

void main() {
  test('gọi /bookings/mine bằng Bearer token và parse danh sách', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode([
          {
            'bookingId': 'b-1',
            'vehicleName': 'Toyota Vios',
            'plateNumber': '51A-123.45',
            'rentalType': 'Daily',
            'startAt': '2026-10-30T01:00:00Z',
            'endAt': '2026-10-31T01:00:00Z',
            'totalAmount': 900000,
            'currency': 'VND',
            'status': 'ReadyForPickup',
            'createdAt': '2026-10-29T01:00:00Z',
          },
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final api = HttpTrackingApi(
      client: client,
      baseUrl: 'http://example.test/api/',
    );
    final bookings = await api.getMyBookings('access-token');

    expect(captured.method, 'GET');
    expect(captured.url.toString(), 'http://example.test/api/bookings/mine');
    expect(captured.headers['Authorization'], 'Bearer access-token');
    expect(bookings, hasLength(1));
    expect(bookings.single.vehicleName, 'Toyota Vios');
    expect(bookings.single.canTrackPickup, isTrue);
  });

  test('gọi snapshot đúng đường dẫn và parse dữ liệu', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'bookingId': 'b-1',
          'stage': 'return',
          'latitude': 10.1,
          'longitude': 106.2,
          'recordedAt': '2026-10-29T03:00:00Z',
          'destinationLatitude': 10.3,
          'destinationLongitude': 106.4,
          'distanceMeters': 120,
          'arrived': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = HttpTrackingApi(
      client: client,
      baseUrl: 'http://example.test/api',
    );
    final snapshot = await api.getSnapshot('b-1', 'access-token');

    expect(
      captured.url.toString(),
      'http://example.test/api/bookings/b-1/tracking/snapshot',
    );
    expect(captured.headers['Authorization'], 'Bearer access-token');
    expect(snapshot.stage, TrackingStage.returnTrip);
    expect(snapshot.distanceMeters, 120);
  });

  test('ProblemDetails 503 giữ mã lỗi để app chờ SignalR', () async {
    final client = MockClient((_) async {
      final body = jsonEncode({
        'title': 'POSITION_NOT_AVAILABLE',
        'detail': 'Traccar chưa nhận được vị trí GPS mới.',
        'status': 503,
      });
      return http.Response.bytes(
        utf8.encode(body),
        503,
        headers: {'content-type': 'application/problem+json; charset=utf-8'},
      );
    });

    final api = HttpTrackingApi(
      client: client,
      baseUrl: 'http://example.test/api',
    );

    try {
      await api.getSnapshot('b-1', 'access-token');
      fail('Phải ném TrackingApiException');
    } on TrackingApiException catch (error) {
      expect(error.statusCode, 503);
      expect(error.code, 'POSITION_NOT_AVAILABLE');
      expect(error.canStillWatchRealtime, isTrue);
      expect(error.displayMessage, contains('GPS'));
    }
  });

  test('401 là phiên hết hạn, 404 booking không phải lỗi phiên', () async {
    Future<TrackingApiException> errorFor(int status, String title) async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'title': title, 'detail': 'detail', 'status': status}),
          status,
          headers: {'content-type': 'application/problem+json'},
        ),
      );
      final api = HttpTrackingApi(
        client: client,
        baseUrl: 'http://example.test/api',
      );
      try {
        await api.getSnapshot('b-1', 'access-token');
        fail('Phải ném TrackingApiException');
      } on TrackingApiException catch (error) {
        return error;
      }
    }

    final unauthorized = await errorFor(401, 'UNAUTHORIZED');
    expect(unauthorized.isSessionExpired, isTrue);
    expect(unauthorized.isUnauthorized, isTrue);

    final notFound = await errorFor(404, 'BOOKING_NOT_FOUND');
    expect(notFound.isSessionExpired, isFalse);
    expect(notFound.isUnauthorized, isFalse);
  });

  test('gọi tracking/status để biết khi nào bản đồ mở', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'bookingId': 'b-1',
          'viewerRole': 'Customer',
          'stage': 'pickup',
          'state': 'WindowNotOpen',
          'canTrack': false,
          'opensAt': '2026-10-29T02:30:00Z',
          'deadline': '2026-10-29T04:00:00Z',
          'secondsUntilOpen': 900,
          'meetingPointsConfigured': true,
          'trackerConfigured': true,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final api = HttpTrackingApi(
      client: client,
      baseUrl: 'http://example.test/api',
    );
    final status = await api.getStatus('b-1', 'access-token');

    expect(
      captured.url.toString(),
      'http://example.test/api/bookings/b-1/tracking/status',
    );
    expect(captured.headers['Authorization'], 'Bearer access-token');
    expect(status.canTrack, isFalse);
    expect(status.state, 'WindowNotOpen');
    expect(status.secondsUntilOpen, 900);
    expect(status.meetingPointsConfigured, isTrue);
  });
}
