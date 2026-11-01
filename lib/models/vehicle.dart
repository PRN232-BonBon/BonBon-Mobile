// Model cho `/api/vehicles` và `/api/vehicles/mine`.

class VehicleSummary {
  const VehicleSummary({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.bodyType,
    required this.seats,
    required this.transmission,
    required this.fuel,
    required this.pickupAddress,
    required this.description,
    required this.dayPrice,
    required this.hourPrice,
    this.features = const [],
    this.imageUrls = const [],
    this.weeklyDiscountEnabled = false,
    this.weeklyDiscountPercent,
    this.mileageLimitEnabled = false,
    this.dailyMileageLimitKm,
    this.overageFeePerKm,
    this.rentalTerms,
  });

  factory VehicleSummary.fromJson(Map<String, dynamic> json) => VehicleSummary(
    id: (json['id'] ?? '').toString(),
    brand: (json['brand'] ?? '').toString(),
    model: (json['model'] ?? '').toString(),
    year: _toInt(json['year']),
    bodyType: (json['bodyType'] ?? '').toString(),
    seats: _toInt(json['seats']),
    transmission: (json['transmission'] ?? '').toString(),
    fuel: (json['fuel'] ?? '').toString(),
    pickupAddress: (json['pickupAddress'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    dayPrice: _toDouble(json['dayPrice']),
    hourPrice: _toDouble(json['hourPrice']),
    features: _toStringList(json['features']),
    imageUrls: _toStringList(json['imageUrls']),
    weeklyDiscountEnabled: json['weeklyDiscountEnabled'] == true,
    weeklyDiscountPercent: _maybeDouble(json['weeklyDiscountPercent']),
    mileageLimitEnabled: json['mileageLimitEnabled'] == true,
    dailyMileageLimitKm: _maybeInt(json['dailyMileageLimitKm']),
    overageFeePerKm: _maybeDouble(json['overageFeePerKm']),
    rentalTerms: _nonEmpty(json['rentalTerms']),
  );

  final String id;
  final String brand;
  final String model;
  final int year;
  final String bodyType;
  final int seats;
  final String transmission;
  final String fuel;
  final String pickupAddress;
  final String description;
  final double dayPrice;
  final double hourPrice;
  final List<String> features;
  final List<String> imageUrls;
  final bool weeklyDiscountEnabled;
  final double? weeklyDiscountPercent;
  final bool mileageLimitEnabled;
  final int? dailyMileageLimitKm;
  final double? overageFeePerKm;
  final String? rentalTerms;

  String get name => '$brand $model'.trim();

  String? get imageUrl => imageUrls.isEmpty ? null : imageUrls.first;
}

class OwnerVehicle {
  const OwnerVehicle({
    required this.vehicleId,
    required this.brand,
    required this.model,
    required this.plateNumber,
    required this.status,
    required this.imageCount,
    this.rejectionReason,
  });

  factory OwnerVehicle.fromJson(Map<String, dynamic> json) => OwnerVehicle(
    vehicleId: (json['vehicleId'] ?? '').toString(),
    brand: (json['brand'] ?? '').toString(),
    model: (json['model'] ?? '').toString(),
    plateNumber: (json['plateNumber'] ?? '').toString(),
    status: (json['status'] ?? '').toString(),
    rejectionReason: _nonEmpty(json['rejectionReason']),
    imageCount: _toInt(json['imageCount']),
  );

  final String vehicleId;
  final String brand;
  final String model;
  final String plateNumber;
  final String status;
  final String? rejectionReason;
  final int imageCount;

  String get name => '$brand $model'.trim();
}

String vehicleStatusLabel(String status) => switch (status) {
  'Available' => 'Đang hiển thị',
  'Pending' => 'Chờ duyệt',
  'Rejected' => 'Bị từ chối',
  'Unavailable' => 'Tạm ẩn',
  'Suspended' => 'Tạm ngưng',
  _ => status.isEmpty ? 'Không rõ' : status,
};

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

List<String> _toStringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
