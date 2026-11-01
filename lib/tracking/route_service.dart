import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class DrivingRoute {
  const DrivingRoute({
    required this.points,
    required this.distanceMeters,
    required this.duration,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final Duration duration;
}

/// Tuyến đường lái xe từ OSRM (dịch vụ công cộng, phù hợp đồ án).
///
/// Backend đã trả khoảng cách đường chim bay; OSRM chỉ bổ sung đường đi và ETA
/// trực quan. Nếu OSRM lỗi, app vẫn hiển thị vị trí + khoảng cách từ backend.
class RouteService {
  RouteService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const _userAgent = 'BonBon-Mobile/1.0 (PRN232 student project)';
  static const _osrmBase = 'https://router.project-osrm.org/route/v1/driving';

  final http.Client _client;
  final bool _ownsClient;

  /// Trình duyệt không cho đặt User-Agent, nên chỉ gửi header này trên mobile.
  Map<String, String> get _headers =>
      kIsWeb ? const {} : const {'User-Agent': _userAgent};

  Future<DrivingRoute?> drivingRoute(LatLng from, LatLng to) async {
    final uri = Uri.parse(
      '$_osrmBase/${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson&alternatives=false&steps=false',
    );

    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;
      return parseOsrmRoute(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  static DrivingRoute? parseOsrmRoute(Map<String, dynamic> json) {
    final routes = json['routes'];
    if (routes is! List || routes.isEmpty) return null;

    final route = routes.first;
    if (route is! Map) return null;

    final distance = (route['distance'] as num?)?.toDouble();
    final duration = (route['duration'] as num?)?.toDouble();
    final geometry = route['geometry'];
    final coordinates = geometry is Map ? geometry['coordinates'] : null;
    if (coordinates is! List) return null;

    final points = <LatLng>[];
    for (final coordinate in coordinates) {
      if (coordinate is! List || coordinate.length < 2) continue;
      final lng = coordinate[0];
      final lat = coordinate[1];
      if (lat is! num || lng is! num) continue;
      points.add(LatLng(lat.toDouble(), lng.toDouble()));
    }
    if (points.isEmpty) return null;

    return DrivingRoute(
      points: points,
      distanceMeters: distance ?? _polylineLength(points),
      duration: Duration(seconds: (duration ?? 0).round()),
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  static double _polylineLength(List<LatLng> points) {
    var total = 0.0;
    const distance = Distance();
    for (var i = 1; i < points.length; i++) {
      total += distance.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return total;
  }
}
