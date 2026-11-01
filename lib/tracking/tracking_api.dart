import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'tracking_models.dart';

class TrackingApiException implements Exception {
  const TrackingApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  /// Chỉ 401 mới cần đăng nhập lại; 403 là không có quyền với booking này.
  bool get isSessionExpired => statusCode == 401;
  bool get isTrackingNotActive => code == 'TRACKING_NOT_ACTIVE';
  bool get isTrackerNotConfigured => code == 'TRACKER_NOT_CONFIGURED';
  bool get isMeetingPointNotConfigured =>
      code == 'MEETING_POINT_NOT_CONFIGURED';
  bool get isPositionNotAvailable => code == 'POSITION_NOT_AVAILABLE';
  bool get canStillWatchRealtime => isPositionNotAvailable;

  String get displayMessage => switch (code) {
    'TRACKING_NOT_ACTIVE' =>
      'Chỉ có thể gửi hoặc xem vị trí khi booking ở trạng thái Đang thuê.',
    'TRACKER_NOT_CONFIGURED' =>
      'Xe chưa được liên kết thiết bị GPS Traccar. Chủ xe cần gắn thiết bị '
          'trước khi theo dõi.',
    'MEETING_POINT_NOT_CONFIGURED' =>
      'Chủ xe chưa thiết lập toạ độ điểm hẹn cho chuyến này.',
    'POSITION_NOT_AVAILABLE' =>
      'Điện thoại người thuê chưa gửi vị trí GPS. Bản đồ sẽ tự cập nhật khi có tín hiệu.',
    'BOOKING_NOT_FOUND' =>
      'Không tìm thấy chuyến hoặc tài khoản này không thuộc chuyến.',
    _ => message,
  };

  @override
  String toString() => 'TrackingApiException($statusCode, $code): $message';
}

abstract interface class TrackingApi {
  Future<List<CustomerBooking>> getMyBookings(String accessToken);

  Future<List<OwnerBooking>> getOwnerBookings(String accessToken);

  Future<void> reportPosition(
    String bookingId,
    String accessToken, {
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    DateTime? recordedAt,
  });

  Future<TrackingSnapshot> getSnapshot(String bookingId, String accessToken);

  /// Trạng thái mở bản đồ (mở lúc nào, thiếu cấu hình gì) — gọi trước snapshot.
  Future<TrackingStatus> getStatus(String bookingId, String accessToken);
}

class HttpTrackingApi implements TrackingApi {
  HttpTrackingApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = _normalizeBase(baseUrl ?? AppConfig.apiBaseUrl),
      _ownsClient = client == null;

  final http.Client _client;
  final String _baseUrl;
  final bool _ownsClient;

  static String _normalizeBase(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  @override
  Future<List<CustomerBooking>> getMyBookings(String accessToken) async {
    final response = await _get('/bookings/mine', accessToken);
    final decoded = _decodeBody(response);
    if (decoded is! List) {
      throw const TrackingApiException(
        statusCode: 0,
        code: 'INVALID_RESPONSE',
        message: 'Máy chủ trả về dữ liệu chuyến không hợp lệ.',
      );
    }
    return decoded
        .whereType<Map>()
        .map((item) => CustomerBooking.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  @override
  Future<List<OwnerBooking>> getOwnerBookings(String accessToken) async {
    final response = await _get('/bookings/owner', accessToken);
    final decoded = _decodeBody(response);
    if (decoded is! List) throw const TrackingApiException(statusCode: 0,
        code: 'INVALID_RESPONSE', message: 'Danh sách booking chủ xe không hợp lệ.');
    return decoded.whereType<Map>().map((item) => OwnerBooking.fromJson(
        item.cast<String, dynamic>())).toList(growable: false);
  }

  @override
  Future<void> reportPosition(String bookingId, String accessToken, {
    required double latitude, required double longitude,
    double? accuracyMeters, DateTime? recordedAt,
  }) async {
    final path = '/bookings/${Uri.encodeComponent(bookingId)}/tracking/positions';
    try {
      final response = await _client.post(_uri(path), headers: {
        'Accept': 'application/json', 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      }, body: jsonEncode({
        'latitude': latitude, 'longitude': longitude,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
        if (recordedAt != null) 'recordedAt': recordedAt.toUtc().toIso8601String(),
      })).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _problemFrom(response);
      }
    } on TrackingApiException { rethrow; }
    on TimeoutException { throw const TrackingApiException(statusCode: 0, code: 'NETWORK', message: 'Máy chủ phản hồi quá lâu.'); }
    on Exception { throw const TrackingApiException(statusCode: 0, code: 'NETWORK', message: 'Không kết nối được tới máy chủ BonBon.'); }
  }

  @override
  Future<TrackingSnapshot> getSnapshot(
    String bookingId,
    String accessToken,
  ) async {
    final response = await _get(
      '/bookings/${Uri.encodeComponent(bookingId)}/tracking/snapshot',
      accessToken,
    );
    final decoded = _decodeBody(response);
    if (decoded is! Map) {
      throw const TrackingApiException(
        statusCode: 0,
        code: 'INVALID_RESPONSE',
        message: 'Máy chủ trả về vị trí không hợp lệ.',
      );
    }
    return TrackingSnapshot.fromJson(decoded.cast<String, dynamic>());
  }

  @override
  Future<TrackingStatus> getStatus(
    String bookingId,
    String accessToken,
  ) async {
    final response = await _get(
      '/bookings/${Uri.encodeComponent(bookingId)}/tracking/status',
      accessToken,
    );
    final decoded = _decodeBody(response);
    if (decoded is! Map) {
      throw const TrackingApiException(
        statusCode: 0,
        code: 'INVALID_RESPONSE',
        message: 'Máy chủ trả về trạng thái theo dõi không hợp lệ.',
      );
    }
    return TrackingStatus.fromJson(decoded.cast<String, dynamic>());
  }

  Future<http.Response> _get(String path, String accessToken) async {
    try {
      final response = await _client
          .get(
            _uri(path),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw _problemFrom(response);
    } on TrackingApiException {
      rethrow;
    } on TimeoutException {
      throw const TrackingApiException(
        statusCode: 0,
        code: 'NETWORK',
        message: 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
      );
    } on Exception {
      throw const TrackingApiException(
        statusCode: 0,
        code: 'NETWORK',
        message: 'Không kết nối được tới máy chủ BonBon.',
      );
    }
  }

  Object? _decodeBody(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  TrackingApiException _problemFrom(http.Response response) {
    final decoded = _decodeBody(response);
    final problem = decoded is Map ? decoded.cast<String, dynamic>() : null;

    String? validationMessage;
    final errors = problem?['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List) {
          final first = value.firstWhere(
            (item) => item != null && item.toString().trim().isNotEmpty,
            orElse: () => null,
          );
          if (first != null) {
            validationMessage = first.toString();
            break;
          }
        }
      }
    }

    final code = (problem?['title'] as String?)?.trim();
    final detail = (problem?['detail'] as String?)?.trim();
    final message =
        validationMessage ??
        (detail == null || detail.isEmpty ? null : detail) ??
        (code == null || code.isEmpty ? null : code) ??
        'Không thể tải dữ liệu theo dõi. Vui lòng thử lại.';

    return TrackingApiException(
      statusCode: response.statusCode,
      code: code ?? 'HTTP_${response.statusCode}',
      message: message,
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

/// Ghép đường dẫn ảnh tương đối (`/api/...`) với origin của backend.
String? resolveMediaUrl(String? value, {String? baseUrl}) {
  final path = value?.trim();
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;

  final base = (baseUrl ?? AppConfig.apiBaseUrl)
      .replaceFirst(RegExp(r'/api/?$'), '')
      .replaceFirst(RegExp(r'/$'), '');
  if (path.startsWith('/')) return '$base$path';
  return '$base/$path';
}
