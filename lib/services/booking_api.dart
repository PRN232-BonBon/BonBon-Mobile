import 'package:http/http.dart' as http;

import '../models/booking.dart';
import 'api_client.dart';

/// Các endpoint `/api/bookings` dùng cho luồng đặt xe.
abstract interface class BookingApi {
  /// `POST /api/bookings/validate-window` — tính số ngày/giờ tính tiền.
  Future<RentalWindow> validateWindow(RentalWindowRequest request);

  /// `POST /api/bookings/quote` — báo giá và cho biết xe còn trống không.
  Future<BookingQuote> quote(String vehicleId, RentalWindowRequest request);

  /// `GET /api/bookings/availability` — kiểm tra lịch trống trước khi đặt.
  Future<bool> isAvailable(String vehicleId, RentalWindowRequest request);

  /// `POST /api/bookings` — tạo chuyến thuê, cần Bearer token.
  Future<CreatedBooking> create(
    String vehicleId,
    RentalWindowRequest request,
    String accessToken,
  );
}

class HttpBookingApi implements BookingApi {
  HttpBookingApi({http.Client? client, String? baseUrl})
    : _api = JsonApiClient(client: client, baseUrl: baseUrl);

  final JsonApiClient _api;

  @override
  Future<RentalWindow> validateWindow(RentalWindowRequest request) async {
    final decoded = await _api.post(
      '/bookings/validate-window',
      body: request.toJson(),
    );
    return RentalWindow.fromJson(_map(decoded));
  }

  @override
  Future<BookingQuote> quote(
    String vehicleId,
    RentalWindowRequest request,
  ) async {
    final decoded = await _api.post(
      '/bookings/quote',
      body: {'vehicleId': vehicleId, ...request.toJson()},
    );
    return BookingQuote.fromJson(_map(decoded));
  }

  @override
  Future<bool> isAvailable(
    String vehicleId,
    RentalWindowRequest request,
  ) async {
    final query = Uri(
      queryParameters: {
        'vehicleId': vehicleId,
        'rentalType': request.rentalType,
        'startAt': request.startAt.toUtc().toIso8601String(),
        'endAt': request.endAt.toUtc().toIso8601String(),
      },
    ).query;
    final decoded = await _api.get('/bookings/availability?$query');
    return decoded is Map && decoded['isAvailable'] == true;
  }

  @override
  Future<CreatedBooking> create(
    String vehicleId,
    RentalWindowRequest request,
    String accessToken,
  ) async {
    final decoded = await _api.post(
      '/bookings',
      body: {'vehicleId': vehicleId, ...request.toJson()},
      accessToken: accessToken,
    );
    return CreatedBooking.fromJson(_map(decoded));
  }

  static Map<String, dynamic> _map(Object? decoded) {
    if (decoded is! Map) return const {};
    return decoded.cast<String, dynamic>();
  }

  void close() => _api.close();
}
