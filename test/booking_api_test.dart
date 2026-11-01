import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bonbon_mobile/models/auth.dart';
import 'package:bonbon_mobile/models/booking.dart';
import 'package:bonbon_mobile/services/booking_api.dart';
import 'package:bonbon_mobile/services/vehicle_api.dart';

const _vehicleId = '4f4c1f9e-8b0a-4f7b-9c3d-2a1b3c4d5e6f';

final _request = RentalWindowRequest(
  rentalType: RentalWindowRequest.daily,
  startAt: DateTime.utc(2026, 11, 1, 2),
  endAt: DateTime.utc(2026, 11, 3, 2),
);

void main() {
  test('catalog gọi GET /vehicles và parse danh sách', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode([
          {
            'id': _vehicleId,
            'brand': 'Toyota',
            'model': 'Vios',
            'year': 2020,
            'bodyType': 'Sedan',
            'seats': 5,
            'transmission': 'Automatic',
            'fuel': 'Petrol',
            'pickupAddress': 'Quận 1, TP.HCM',
            'description': 'Xe sạch sẽ, giao xe đúng giờ.',
            'features': ['Bluetooth'],
            'dayPrice': 900000,
            'hourPrice': 90000,
            'imageUrls': ['/api/vehicles/images/1'],
            'imageUrl': '/api/vehicles/images/1',
            'weeklyDiscountEnabled': true,
            'weeklyDiscountPercent': 10,
            'mileageLimitEnabled': true,
            'dailyMileageLimitKm': 300,
            'overageFeePerKm': 3000,
            'rentalTerms': 'Không hút thuốc',
            'rating': 0,
            'completedTrips': 0,
            'depositFree': false,
            'deliveryAvailable': false,
            'instantBook': false,
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = HttpVehicleApi(
      client: client,
      baseUrl: 'http://example.test/api',
    );
    final vehicles = await api.getCatalog();

    expect(captured.method, 'GET');
    expect(captured.url.toString(), 'http://example.test/api/vehicles');
    expect(captured.headers.containsKey('Authorization'), isFalse);
    expect(vehicles.single.name, 'Toyota Vios');
    expect(vehicles.single.dayPrice, 900000);
    expect(vehicles.single.imageUrl, '/api/vehicles/images/1');
  });

  test('xe của tôi gắn Bearer token', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode([
          {
            'vehicleId': _vehicleId,
            'brand': 'Honda',
            'model': 'City',
            'plateNumber': '51A-123.45',
            'status': 'Pending',
            'rejectionReason': null,
            'imageCount': 3,
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = HttpVehicleApi(
      client: client,
      baseUrl: 'http://example.test/api',
    );
    final vehicles = await api.getMine('access-token');

    expect(captured.url.toString(), 'http://example.test/api/vehicles/mine');
    expect(captured.headers['Authorization'], 'Bearer access-token');
    expect(vehicles.single.plateNumber, '51A-123.45');
    expect(vehicles.single.imageCount, 3);
  });

  test('validate-window gửi body ISO-8601 và đọc số ngày', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'rentalType': 'Daily',
          'startAt': '2026-11-01T02:00:00Z',
          'endAt': '2026-11-03T02:00:00Z',
          'billableUnits': 2,
          'unitLabel': 'ngày',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = HttpBookingApi(
      client: client,
      baseUrl: 'http://example.test/api',
    );
    final window = await api.validateWindow(_request);

    expect(
      captured.url.toString(),
      'http://example.test/api/bookings/validate-window',
    );
    expect(jsonDecode(captured.body), {
      'rentalType': 'Daily',
      'startAt': '2026-11-01T02:00:00.000Z',
      'endAt': '2026-11-03T02:00:00.000Z',
    });
    expect(window.billableLabel, '2 ngày');
  });

  test('quote gửi vehicleId kèm khoảng thuê và parse báo giá', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'vehicleId': _vehicleId,
          'rentalType': 'Daily',
          'startAt': '2026-11-01T02:00:00Z',
          'endAt': '2026-11-03T02:00:00Z',
          'billableUnits': 2,
          'unitPrice': 900000,
          'baseRentalAmount': 1800000,
          'weeklyDiscountPercent': 0,
          'discountAmount': 0,
          'quotedRentalAmount': 1800000,
          'includedMileageKm': 600,
          'overageFeePerKm': 3000,
          'rentalTerms': 'Không hút thuốc',
          'currency': 'VND',
          'isAvailable': true,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = HttpBookingApi(
      client: client,
      baseUrl: 'http://example.test/api',
    );
    final quote = await api.quote(_vehicleId, _request);

    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'http://example.test/api/bookings/quote');
    expect(jsonDecode(captured.body), {
      'vehicleId': _vehicleId,
      'rentalType': 'Daily',
      'startAt': '2026-11-01T02:00:00.000Z',
      'endAt': '2026-11-03T02:00:00.000Z',
    });
    expect(quote.quotedRentalAmount, 1800000);
    expect(quote.includedMileageKm, 600);
    expect(quote.isAvailable, isTrue);
  });

  test('availability gọi GET với query và đọc isAvailable', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'isAvailable': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = HttpBookingApi(
      client: client,
      baseUrl: 'http://example.test/api',
    );
    final available = await api.isAvailable(_vehicleId, _request);

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/bookings/availability');
    expect(captured.url.queryParameters['vehicleId'], _vehicleId);
    expect(captured.url.queryParameters['rentalType'], 'Daily');
    expect(
      captured.url.queryParameters['startAt'],
      '2026-11-01T02:00:00.000Z',
    );
    expect(available, isFalse);
  });

  test('tạo booking gắn Bearer token và parse kết quả', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'bookingId': _vehicleId,
          'vehicleId': _vehicleId,
          'rentalType': 'Daily',
          'startAt': '2026-11-01T02:00:00Z',
          'endAt': '2026-11-03T02:00:00Z',
          'billableUnits': 2,
          'unitPrice': 900000,
          'baseRentalAmount': 1800000,
          'weeklyDiscountPercent': 0,
          'discountAmount': 0,
          'quotedRentalAmount': 1800000,
          'includedMileageKm': 600,
          'overageFeePerKm': 3000,
          'rentalTerms': 'Không hút thuốc',
          'currency': 'VND',
          'status': 'PendingApproval',
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = HttpBookingApi(
      client: client,
      baseUrl: 'http://example.test/api',
    );
    final created = await api.create(_vehicleId, _request, 'access-token');

    expect(captured.url.toString(), 'http://example.test/api/bookings');
    expect(captured.headers['Authorization'], 'Bearer access-token');
    expect(created.status, 'PendingApproval');
    expect(created.shortCode, '4F4C1F9E');
  });

  test('lỗi ProblemDetails của booking thành ApiException có detail', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'title': 'SCHEDULE_CONFLICT',
          'detail': 'Xe đã có lịch trong khoảng thời gian này.',
          'status': 400,
        }),
        400,
        headers: {'content-type': 'application/problem+json; charset=utf-8'},
      ),
    );

    final api = HttpBookingApi(
      client: client,
      baseUrl: 'http://example.test/api',
    );

    expect(
      () => api.quote(_vehicleId, _request),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 400)
            .having(
              (e) => e.message,
              'message',
              'Xe đã có lịch trong khoảng thời gian này.',
            ),
      ),
    );
  });
}
