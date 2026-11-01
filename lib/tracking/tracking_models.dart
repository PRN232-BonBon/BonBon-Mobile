/// Models của luồng GPS điện thoại -> API backend -> SignalR cho chủ xe.
library;

enum TrackingStage {
  pickup('pickup', 'Xe đang tới điểm lấy', 'Người thuê đang theo dõi'),
  returnTrip('return', 'Xe đang về điểm trả', 'Chủ xe đang theo dõi');

  const TrackingStage(this.wire, this.label, this.viewerLabel);

  final String wire;
  final String label;
  final String viewerLabel;

  static TrackingStage fromWire(Object? value) =>
      value == returnTrip.wire ? returnTrip : pickup;
}

class TrackingSnapshot {
  const TrackingSnapshot({
    required this.bookingId,
    required this.stage,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.distanceMeters,
    required this.arrived,
    this.accuracyMeters,
  });

  factory TrackingSnapshot.fromJson(Map<String, dynamic> json) {
    final latitude = _toDouble(json['latitude']);
    final longitude = _toDouble(json['longitude']);
    final destinationLatitude = _toDouble(json['destinationLatitude']);
    final destinationLongitude = _toDouble(json['destinationLongitude']);
    return TrackingSnapshot(
      bookingId: (json['bookingId'] ?? '').toString(),
      stage: TrackingStage.fromWire(json['stage']),
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: _maybeDouble(json['accuracyMeters']),
      recordedAt: _toDate(json['recordedAt']),
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      distanceMeters: _toDouble(json['distanceMeters']),
      arrived: json['arrived'] == true,
    );
  }

  final String bookingId;
  final TrackingStage stage;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime recordedAt;
  final double destinationLatitude;
  final double destinationLongitude;
  final double distanceMeters;
  final bool arrived;
}

class CustomerBooking {
  const CustomerBooking({
    required this.bookingId,
    required this.vehicleName,
    required this.plateNumber,
    required this.rentalType,
    required this.startAt,
    required this.endAt,
    required this.totalAmount,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.coverImageUrl,
  });

  factory CustomerBooking.fromJson(Map<String, dynamic> json) =>
      CustomerBooking(
        bookingId: (json['bookingId'] ?? '').toString(),
        vehicleName: (json['vehicleName'] ?? '').toString(),
        plateNumber: (json['plateNumber'] ?? '').toString(),
        coverImageUrl: _nonEmpty(json['coverImageUrl']),
        rentalType: (json['rentalType'] ?? '').toString(),
        startAt: _toDate(json['startAt']),
        endAt: _toDate(json['endAt']),
        totalAmount: _toDouble(json['totalAmount']),
        currency: (json['currency'] ?? 'VND').toString(),
        status: (json['status'] ?? '').toString(),
        createdAt: _toDate(json['createdAt']),
      );

  final String bookingId;
  final String vehicleName;
  final String plateNumber;
  final String? coverImageUrl;
  final String rentalType;
  final DateTime startAt;
  final DateTime endAt;
  final double totalAmount;
  final String currency;
  final String status;
  final DateTime createdAt;

  bool get canTrackPickup => status == 'ReadyForPickup';
  bool get canShareLiveLocation => status == 'InProgress';

  TrackingTarget get target => TrackingTarget(
    bookingId: bookingId,
    vehicleName: vehicleName,
    plateNumber: plateNumber,
    status: status,
  );
}

class OwnerBooking {
  const OwnerBooking({required this.bookingId, required this.vehicleName,
    required this.plateNumber, required this.customerName, required this.status});
  factory OwnerBooking.fromJson(Map<String, dynamic> json) => OwnerBooking(
    bookingId: (json['bookingId'] ?? '').toString(),
    vehicleName: (json['vehicleName'] ?? '').toString(),
    plateNumber: (json['plateNumber'] ?? '').toString(),
    customerName: (json['customerName'] ?? '').toString(),
    status: (json['status'] ?? '').toString());
  final String bookingId, vehicleName, plateNumber, customerName, status;
  bool get canTrack => status == 'InProgress';
  TrackingTarget get target => TrackingTarget(bookingId: bookingId,
    vehicleName: vehicleName, plateNumber: plateNumber, status: status);
}

/// Chuyến cần mở bản đồ. Chủ xe có thể mở bằng mã booking nên không phải lúc
/// nào cũng có tên xe/trạng thái.
class TrackingTarget {
  const TrackingTarget({
    required this.bookingId,
    this.vehicleName = 'Chuyến thuê xe',
    this.plateNumber = '',
    this.status,
  });

  final String bookingId;
  final String vehicleName;
  final String plateNumber;
  final String? status;

  String get title =>
      plateNumber.isEmpty ? vehicleName : '$vehicleName · $plateNumber';

  String get shortCode =>
      (bookingId.length > 8 ? bookingId.substring(0, 8) : bookingId)
          .toUpperCase();
}

String bookingStatusLabel(String status) => switch (status) {
  'PendingApproval' => 'Chờ duyệt',
  'AwaitingPayment' => 'Chờ thanh toán',
  'Confirmed' => 'Đã xác nhận',
  'ReadyForPickup' => 'Sẵn sàng nhận xe',
  'InProgress' => 'Đang trong chuyến',
  'Returned' => 'Đã trả xe',
  'AwaitingSettlement' => 'Chờ quyết toán',
  'Completed' => 'Hoàn tất',
  'Cancelled' => 'Đã huỷ',
  _ => status.isEmpty ? 'Không rõ' : status,
};

String bookingStatusHint(CustomerBooking booking) => switch (booking.status) {
  'ReadyForPickup' =>
    'Xe đang được giao tới điểm lấy. Mở bản đồ để xem vị trí realtime.',
  'Confirmed' =>
    'Chủ xe đã xác nhận. Khi xe bắt đầu di chuyển tới điểm lấy, nút theo '
        'dõi sẽ xuất hiện.',
  'InProgress' =>
    'Bạn đang trong chuyến. Chủ xe canh vị trí trả xe trên hệ thống.',
  'AwaitingPayment' => 'Hoàn tất thanh toán để chủ xe chuẩn bị giao xe.',
  'Returned' ||
  'AwaitingSettlement' => 'Chuyến đã kết thúc, không còn theo dõi trực tiếp.',
  'Completed' => 'Chuyến đã hoàn tất.',
  'Cancelled' => 'Chuyến đã bị huỷ.',
  _ => 'Chưa có thông tin theo dõi cho trạng thái này.',
};

String rentalTypeLabel(String rentalType) =>
    rentalType == 'Hourly' ? 'Thuê theo giờ' : 'Thuê theo ngày';

String formatBookingWindow(DateTime startAt, DateTime endAt) {
  final start = startAt.toLocal();
  final end = endAt.toLocal();
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  return sameDay
      ? '${_date(start)} · ${_time(start)} – ${_time(end)}'
      : '${_date(start)} ${_time(start)} – ${_date(end)} ${_time(end)}';
}

String formatMoney(double amount, String currency) {
  final value = amount.round().toString();
  final grouped = value.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return currency == 'VND' ? '$grouped ₫' : '$grouped $currency';
}

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  final value = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
  return '${value.replaceAll('.', ',')} km';
}

String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 1) return '< 1 phút';
  if (minutes < 60) return '~$minutes phút';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '~$hours giờ' : '~$hours giờ $rest phút';
}

Duration estimateDuration(double meters) {
  const averageSpeedKmh = 25.0;
  final seconds = meters / (averageSpeedKmh / 3.6);
  return Duration(seconds: seconds.round().clamp(30, 60 * 60 * 6));
}

String formatRelativeTime(DateTime time) {
  final seconds = DateTime.now().difference(time.toLocal()).inSeconds;
  if (seconds < 5) return 'vừa xong';
  if (seconds < 60) return '$seconds giây trước';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes phút trước';
  final hours = minutes ~/ 60;
  if (hours < 24) return '$hours giờ trước';
  return '${hours ~/ 24} ngày trước';
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}';

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

double _toDouble(Object? value) => _maybeDouble(value) ?? 0;

double? _maybeDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime _toDate(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

/// Trạng thái tracking của một booking — `GET /bookings/{id}/tracking/status`.
///
/// Cho biết bản đồ có mở được không, mở lúc nào, còn thiếu cấu hình gì — để app
/// báo lý do kèm đếm ngược thay vì gọi snapshot rồi nhận lỗi 409/503.
class TrackingStatus {
  const TrackingStatus({
    required this.bookingId,
    required this.viewerRole,
    required this.stage,
    required this.state,
    required this.canTrack,
    required this.opensAt,
    required this.deadline,
    required this.secondsUntilOpen,
    required this.meetingPointsConfigured,
    required this.trackerConfigured,
  });

  factory TrackingStatus.fromJson(Map<String, dynamic> json) => TrackingStatus(
    bookingId: (json['bookingId'] ?? '').toString(),
    viewerRole: (json['viewerRole'] ?? '').toString(),
    stage: TrackingStage.fromWire(json['stage']),
    state: (json['state'] ?? '').toString(),
    canTrack: json['canTrack'] == true,
    opensAt: _toDate(json['opensAt']),
    deadline: _toDate(json['deadline']),
    secondsUntilOpen: (json['secondsUntilOpen'] as num?)?.toInt() ?? 0,
    meetingPointsConfigured: json['meetingPointsConfigured'] == true,
    trackerConfigured: json['trackerConfigured'] == true,
  );

  final String bookingId;
  final String viewerRole;
  final TrackingStage stage;
  final String state;
  final bool canTrack;
  final DateTime opensAt;
  final DateTime deadline;
  final int secondsUntilOpen;
  final bool meetingPointsConfigured;
  final bool trackerConfigured;

  bool get isOwnerViewing => viewerRole == 'Owner' || viewerRole == 'VehicleOwner';
}
