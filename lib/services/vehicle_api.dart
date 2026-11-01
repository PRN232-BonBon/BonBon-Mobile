import 'package:http/http.dart' as http;

import '../models/vehicle.dart';
import 'api_client.dart';

/// Các endpoint `/api/vehicles`.
abstract interface class VehicleApi {
  /// Danh mục xe đang cho thuê — `GET /api/vehicles` (không cần đăng nhập).
  Future<List<VehicleSummary>> getCatalog();

  /// Xe của chủ xe đang đăng nhập — `GET /api/vehicles/mine`.
  Future<List<OwnerVehicle>> getMine(String accessToken);
}

class HttpVehicleApi implements VehicleApi {
  HttpVehicleApi({http.Client? client, String? baseUrl})
    : _api = JsonApiClient(client: client, baseUrl: baseUrl);

  final JsonApiClient _api;

  @override
  Future<List<VehicleSummary>> getCatalog() async {
    final decoded = await _api.get('/vehicles');
    return _list(decoded)
        .map((item) => VehicleSummary.fromJson(item))
        .toList(growable: false);
  }

  @override
  Future<List<OwnerVehicle>> getMine(String accessToken) async {
    final decoded = await _api.get('/vehicles/mine', accessToken: accessToken);
    return _list(decoded)
        .map((item) => OwnerVehicle.fromJson(item))
        .toList(growable: false);
  }

  static Iterable<Map<String, dynamic>> _list(Object? decoded) {
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map(
      (item) => item.cast<String, dynamic>(),
    );
  }

  void close() => _api.close();
}
