// Model cho luồng đặt xe: `/api/bookings/*`.

/// Yêu cầu thuê theo ngày hoặc theo giờ.
class RentalWindowRequest {
  const RentalWindowRequest({
    required this.rentalType,
    required this.startAt,
    required this.endAt,
  });

  /// Backend chỉ nhận `Daily` hoặc `Hourly` (tự chuẩn hoá từ chữ thường).
  static const daily = 'Daily';
  static const hourly = 'Hourly';

  final String rentalType;
  final DateTime startAt;
  final DateTime endAt;

  Map<String, dynamic> toJson() => {
    'rentalType': rentalType,
    'startAt': startAt.toUtc().toIso8601String(),
    'endAt': endAt.toUtc().toIso8601String(),
  };
}

/// Kết quả `POST /bookings/validate-window`: số ngày/giờ backend tính được.
class RentalWindow {
  const RentalWindow({
    required this.rentalType,
    required this.startAt,
    required this.endAt,
    required this.billableUnits,
    required this.unitLabel,
  });

  factory RentalWindow.fromJson(Map<String, dynamic> json) => RentalWindow(
    rentalType: (json['rentalType'] ?? '').toString(),
    startAt: _toDate(json['startAt']),
    endAt: _toDate(json['endAt']),
    billableUnits: _toInt(json['billableUnits']),
    unitLabel: (json['unitLabel'] ?? '').toString(),
  );

  final String rentalType;
  final DateTime startAt;
  final DateTime endAt;
  final int billableUnits;
  final String unitLabel;

  String get billableLabel => '$billableUnits $unitLabel';
}

/// Báo giá từ `POST /bookings/quote`.
class BookingQuote {
  const BookingQuote({
    required this.rentalType,
    required this.billableUnits,
    required this.unitPrice,
    required this.baseRentalAmount,
    required this.weeklyDiscountPercent,
    required this.discountAmount,
    required this.quotedRentalAmount,
    required this.currency,
    required this.isAvailable,
    this.includedMileageKm,
    this.overageFeePerKm,
    this.rentalTerms,
  });

  factory BookingQuote.fromJson(Map<String, dynamic> json) => BookingQuote(
    rentalType: (json['rentalType'] ?? '').toString(),
    billableUnits: _toInt(json['billableUnits']),
    unitPrice: _toDouble(json['unitPrice']),
    baseRentalAmount: _toDouble(json['baseRentalAmount']),
    weeklyDiscountPercent: _toDouble(json['weeklyDiscountPercent']),
    discountAmount: _toDouble(json['discountAmount']),
    quotedRentalAmount: _toDouble(json['quotedRentalAmount']),
    includedMileageKm: _maybeInt(json['includedMileageKm']),
    overageFeePerKm: _maybeDouble(json['overageFeePerKm']),
    rentalTerms: (json['rentalTerms'] as String?)?.trim(),
    currency: (json['currency'] ?? 'VND').toString(),
    isAvailable: json['isAvailable'] == true,
  );

  final String rentalType;
  final int billableUnits;
  final double unitPrice;
  final double baseRentalAmount;
  final double weeklyDiscountPercent;
  final double discountAmount;
  final double quotedRentalAmount;
  final int? includedMileageKm;
  final double? overageFeePerKm;
  final String? rentalTerms;
  final String currency;
  final bool isAvailable;
}

/// Booking vừa tạo từ `POST /bookings`.
class CreatedBooking {
  const CreatedBooking({
    required this.bookingId,
    required this.rentalType,
    required this.startAt,
    required this.endAt,
    required this.billableUnits,
    required this.quotedRentalAmount,
    required this.currency,
    required this.status,
  });

  factory CreatedBooking.fromJson(Map<String, dynamic> json) => CreatedBooking(
    bookingId: (json['bookingId'] ?? '').toString(),
    rentalType: (json['rentalType'] ?? '').toString(),
    startAt: _toDate(json['startAt']),
    endAt: _toDate(json['endAt']),
    billableUnits: _toInt(json['billableUnits']),
    quotedRentalAmount: _toDouble(json['quotedRentalAmount']),
    currency: (json['currency'] ?? 'VND').toString(),
    status: (json['status'] ?? '').toString(),
  );

  final String bookingId;
  final String rentalType;
  final DateTime startAt;
  final DateTime endAt;
  final int billableUnits;
  final double quotedRentalAmount;
  final String currency;
  final String status;

  String get shortCode =>
      (bookingId.length > 8 ? bookingId.substring(0, 8) : bookingId)
          .toUpperCase();
}

int _toInt(Object? value) => _maybeInt(value) ?? 0;

int? _maybeInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double _toDouble(Object? value) => _maybeDouble(value) ?? 0;

double? _maybeDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime _toDate(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.fromMillisecondsSinceEpoch(0);
}
