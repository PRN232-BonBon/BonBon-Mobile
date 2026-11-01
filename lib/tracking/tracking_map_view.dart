import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';

const destinationColor = Color(0xFFF59E0B);

class TrackingMapView extends StatelessWidget {
  const TrackingMapView({
    super.key,
    required this.controller,
    required this.center,
    this.zoom = 14,
    this.markers = const [],
    this.polylines = const [],
    this.onTap,
    this.interactionFlags,
  });

  final MapController controller;
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final TapCallback? onTap;
  final int? interactionFlags;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 4,
        maxZoom: 19,
        backgroundColor: AppColors.background,
        onTap: onTap,
        interactionOptions: InteractionOptions(
          flags:
              interactionFlags ??
              (InteractiveFlag.all & ~InteractiveFlag.rotate),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.mapTileUrl,
          userAgentPackageName: 'com.example.bonbon_mobile',
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('© OpenStreetMap contributors'),
            TextSourceAttribution('© CARTO'),
          ],
        ),
      ],
    );
  }
}

Marker vehicleMarker(LatLng point) =>
    Marker(point: point, width: 64, height: 64, child: const _VehiclePin());

Marker destinationMarker(
  LatLng point, {
  String label = 'Điểm hẹn',
  bool active = true,
}) => Marker(
  point: point,
  width: 150,
  height: 80,
  alignment: Alignment.topCenter,
  child: _DestinationPin(label: label, active: active),
);

Polyline routePolyline(List<LatLng> points) => Polyline(
  points: points,
  strokeWidth: 5,
  color: AppColors.primary,
  borderColor: Colors.white,
  borderStrokeWidth: 1.5,
);

Polyline directPolyline(LatLng from, LatLng to) => Polyline(
  points: [from, to],
  strokeWidth: 4,
  color: AppColors.primarySoft,
  pattern: StrokePattern.dashed(segments: [10, 8]),
);

void fitMapToPoints(
  MapController controller,
  Iterable<LatLng> points, {
  EdgeInsets padding = const EdgeInsets.fromLTRB(56, 100, 56, 220),
}) {
  final list = points.toList(growable: false);
  if (list.isEmpty) return;
  if (list.length == 1) {
    controller.move(list.first, 15);
    return;
  }
  controller.fitCamera(
    CameraFit.coordinates(coordinates: list, padding: padding, maxZoom: 16),
  );
}

class _VehiclePin extends StatelessWidget {
  const _VehiclePin();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_car_filled_rounded,
            size: 19,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _DestinationPin extends StatelessWidget {
  const _DestinationPin({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? destinationColor : AppColors.border,
              width: active ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: active ? destinationColor : AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: destinationColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.flag_rounded, size: 16, color: Colors.white),
        ),
      ],
    );
  }
}
