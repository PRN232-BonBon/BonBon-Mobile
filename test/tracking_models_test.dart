import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:bonbon_mobile/tracking/route_service.dart';
import 'package:bonbon_mobile/tracking/tracking_api.dart';
import 'package:bonbon_mobile/tracking/tracking_models.dart';

void main() {
  group('TrackingSnapshot', () {
    test('parse snapshot pickup với số dạng chuỗi từ backend', () {
      final snapshot = TrackingSnapshot.fromJson({
        'bookingId': '4f4c1f9e-8b0a-4f7b-9c3d-2a1b3c4d5e6f',
        'stage': 'pickup',
        'latitude': '10.7769',
        'longitude': 106.7009,
        'accuracyMeters': 8.5,
        'recordedAt': '2026-10-29T03:00:00+00:00',
        'destinationLatitude': '10.78',
        'destinationLongitude': '106.71',
        'distanceMeters': 1234.4,
        'arrived': false,
      });

      expect(snapshot.stage, TrackingStage.pickup);
      expect(snapshot.stage.label, 'Xe đang tới điểm lấy');
      expect(snapshot.latitude, closeTo(10.7769, 0.000001));
      expect(snapshot.longitude, closeTo(106.7009, 0.000001));
      expect(snapshot.accuracyMeters, closeTo(8.5, 0.000001));
      expect(snapshot.destinationLatitude, closeTo(10.78, 0.000001));
      expect(snapshot.distanceMeters, closeTo(1234.4, 0.000001));
      expect(snapshot.arrived, isFalse);
      expect(snapshot.recordedAt.isUtc, isFalse);
      expect(snapshot.recordedAt.toUtc(), DateTime.utc(2026, 10, 29, 3));
    });

    test('stage return, accuracy null và arrived true', () {
      final snapshot = TrackingSnapshot.fromJson({
        'bookingId': 'abc',
        'stage': 'return',
        'latitude': 10.1,
        'longitude': 106.2,
        'recordedAt': '2026-10-29T03:00:00Z',
        'destinationLatitude': 10.3,
        'destinationLongitude': 106.4,
        'distanceMeters': 15,
        'arrived': true,
      });

      expect(snapshot.stage, TrackingStage.returnTrip);
      expect(snapshot.accuracyMeters, isNull);
      expect(snapshot.arrived, isTrue);
    });

    test('stage lạ hoặc thiếu thì mặc định pickup', () {
      expect(TrackingStage.fromWire('khác'), TrackingStage.pickup);
      expect(TrackingStage.fromWire(null), TrackingStage.pickup);
    });
  });

  group('CustomerBooking', () {
    Map<String, dynamic> json({String status = 'ReadyForPickup'}) => {
      'bookingId': 'b-1',
      'vehicleName': 'Toyota Vios',
      'plateNumber': '51A-123.45',
      'coverImageUrl': ' /api/vehicles/1.jpg ',
      'rentalType': 'Hourly',
      'startAt': '2026-10-30T01:00:00Z',
      'endAt': '2026-10-30T05:00:00Z',
      'totalAmount': 800000,
      'currency': 'VND',
      'status': status,
      'createdAt': '2026-10-29T01:00:00Z',
    };

    test('parse đầy đủ, chỉ ReadyForPickup mới theo dõi pickup', () {
      final booking = CustomerBooking.fromJson(json());

      expect(booking.vehicleName, 'Toyota Vios');
      expect(booking.plateNumber, '51A-123.45');
      expect(booking.coverImageUrl, '/api/vehicles/1.jpg');
      expect(booking.totalAmount, 800000);
      expect(booking.canTrackPickup, isTrue);
      expect(booking.target.bookingId, 'b-1');
      expect(booking.target.title, 'Toyota Vios · 51A-123.45');
      expect(booking.target.shortCode, 'B-1');

      expect(
        CustomerBooking.fromJson(json(status: 'InProgress')).canTrackPickup,
        isFalse,
      );
      expect(
        CustomerBooking.fromJson(json(status: 'Confirmed')).canTrackPickup,
        isFalse,
      );
    });

    test('thiếu URL ảnh thì trả null', () {
      final booking = CustomerBooking.fromJson(
        json()..['coverImageUrl'] = '  ',
      );
      expect(booking.coverImageUrl, isNull);
    });
  });

  test('nhãn trạng thái và gợi ý theo backend', () {
    expect(bookingStatusLabel('ReadyForPickup'), 'Sẵn sàng nhận xe');
    expect(bookingStatusLabel('InProgress'), 'Đang trong chuyến');
    expect(bookingStatusLabel('Không có'), 'Không có');
    expect(bookingStatusLabel(''), 'Không rõ');

    final ready = CustomerBooking.fromJson({
      'bookingId': 'b',
      'status': 'ReadyForPickup',
      'startAt': '2026-10-30T01:00:00Z',
      'endAt': '2026-10-30T05:00:00Z',
      'createdAt': '2026-10-29T01:00:00Z',
    });
    expect(bookingStatusHint(ready), contains('Mở bản đồ'));

    final confirmed = CustomerBooking.fromJson({
      'bookingId': 'b',
      'status': 'Confirmed',
      'startAt': '2026-10-30T01:00:00Z',
      'endAt': '2026-10-30T05:00:00Z',
      'createdAt': '2026-10-29T01:00:00Z',
    });
    expect(bookingStatusHint(confirmed), contains('nút theo dõi'));

    expect(rentalTypeLabel('Hourly'), 'Thuê theo giờ');
    expect(rentalTypeLabel('Daily'), 'Thuê theo ngày');
  });

  test('TrackingTarget hiển thị tên xe, biển số và mã ngắn', () {
    const withPlate = TrackingTarget(
      bookingId: '4f4c1f9e-8b0a-4f7b-9c3d-2a1b3c4d5e6f',
      vehicleName: 'VinFast VF5',
      plateNumber: '51K-999.99',
    );
    expect(withPlate.title, 'VinFast VF5 · 51K-999.99');
    expect(withPlate.shortCode, '4F4C1F9E');

    const withoutPlate = TrackingTarget(bookingId: 'abc');
    expect(withoutPlate.title, 'Chuyến thuê xe');
    expect(withoutPlate.shortCode, 'ABC');
  });

  group('định dạng hiển thị', () {
    test('tiền tệ', () {
      expect(formatMoney(800000, 'VND'), '800.000 ₫');
      expect(formatMoney(1234.6, 'USD'), '1.235 USD');
    });

    test('khoảng cách', () {
      expect(formatDistance(350), '350 m');
      expect(formatDistance(2345), '2,3 km');
      expect(formatDistance(23456), '23 km');
    });

    test('thời gian', () {
      expect(formatDuration(const Duration(seconds: 20)), '< 1 phút');
      expect(formatDuration(const Duration(minutes: 12)), '~12 phút');
      expect(formatDuration(const Duration(minutes: 65)), '~1 giờ 5 phút');
      expect(formatDuration(const Duration(minutes: 120)), '~2 giờ');
      expect(estimateDuration(1000).inMinutes, greaterThan(0));
    });

    test('thời gian tương đối', () {
      final now = DateTime.now();
      expect(formatRelativeTime(now), 'vừa xong');
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 5))),
        '5 phút trước',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 2))),
        '2 giờ trước',
      );
    });

    test('khung giờ booking', () {
      final sameDay = formatBookingWindow(
        DateTime(2026, 10, 30, 8, 0),
        DateTime(2026, 10, 30, 12, 30),
      );
      expect(sameDay, '30/10 · 08:00 – 12:30');

      final nextDay = formatBookingWindow(
        DateTime(2026, 10, 30, 8, 0),
        DateTime(2026, 10, 31, 9, 15),
      );
      expect(nextDay, '30/10 08:00 – 31/10 09:15');
    });
  });

  group('TrackingApiException', () {
    test('401/403 là lỗi phiên đăng nhập', () {
      expect(
        const TrackingApiException(
          statusCode: 401,
          code: 'UNAUTHORIZED',
          message: 'x',
        ).isUnauthorized,
        isTrue,
      );
      expect(
        const TrackingApiException(
          statusCode: 403,
          code: 'FORBIDDEN',
          message: 'x',
        ).isUnauthorized,
        isTrue,
      );
      expect(
        const TrackingApiException(
          statusCode: 404,
          code: 'BOOKING_NOT_FOUND',
          message: 'x',
        ).isUnauthorized,
        isFalse,
      );
    });

    test('mã lỗi backend có thông điệp tiếng Việt', () {
      const notActive = TrackingApiException(
        statusCode: 409,
        code: 'TRACKING_NOT_ACTIVE',
        message: 'raw',
      );
      expect(notActive.displayMessage, contains('giai đoạn theo dõi'));
      expect(notActive.canStillWatchRealtime, isFalse);

      const noPosition = TrackingApiException(
        statusCode: 503,
        code: 'POSITION_NOT_AVAILABLE',
        message: 'raw',
      );
      expect(noPosition.displayMessage, contains('GPS chưa gửi vị trí'));
      expect(noPosition.canStillWatchRealtime, isTrue);

      const unknown = TrackingApiException(
        statusCode: 500,
        code: 'SERVER_ERROR',
        message: 'Lỗi máy chủ.',
      );
      expect(unknown.displayMessage, 'Lỗi máy chủ.');
    });
  });

  test('resolveMediaUrl ghép origin của backend', () {
    expect(
      resolveMediaUrl('/api/vehicles/a.jpg', baseUrl: 'http://x:5188/api'),
      'http://x:5188/api/vehicles/a.jpg',
    );
    expect(
      resolveMediaUrl('https://cdn.example.com/a.jpg'),
      'https://cdn.example.com/a.jpg',
    );
    expect(resolveMediaUrl('  '), isNull);
  });

  group('RouteService.parseOsrmRoute', () {
    test('parse đầy đủ', () {
      final route = RouteService.parseOsrmRoute({
        'routes': [
          {
            'distance': 1234.5,
            'duration': 321,
            'geometry': {
              'coordinates': [
                [106.7, 10.78],
                [106.71, 10.79],
              ],
            },
          },
        ],
      });

      expect(route, isNotNull);
      expect(route!.points.length, 2);
      expect(route.points.first.latitude, 10.78);
      expect(route.points.first.longitude, 106.7);
      expect(route.distanceMeters, 1234.5);
      expect(route.duration.inSeconds, 321);
    });

    test('trả null khi dữ liệu rỗng hoặc toạ độ sai', () {
      expect(RouteService.parseOsrmRoute({}), isNull);
      expect(RouteService.parseOsrmRoute({'routes': []}), isNull);
      expect(
        RouteService.parseOsrmRoute({
          'routes': [
            {
              'geometry': {'coordinates': []},
            },
          ],
        }),
        isNull,
      );
      expect(
        RouteService.parseOsrmRoute({
          'routes': [
            {
              'geometry': {
                'coordinates': [
                  ['x', 'y'],
                ],
              },
            },
          ],
        }),
        isNull,
      );
    });

    test('điểm LatLng dùng đúng thứ tự lat/lng', () {
      const point = LatLng(10.78, 106.7);
      expect(point.latitude, 10.78);
      expect(point.longitude, 106.7);
    });
  });
}
