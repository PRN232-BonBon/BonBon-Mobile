import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../state/auth_controller.dart';
import '../theme/app_theme.dart';
import 'route_service.dart';
import 'tracking_api.dart';
import 'tracking_auth_gate.dart';
import 'tracking_hub.dart';
import 'tracking_map_view.dart';
import 'tracking_models.dart';
import 'tracking_widgets.dart';

/// Bản đồ tracking realtime của một booking.
///
/// Chỉ mở khi đã đăng nhập; snapshot và SignalR đều dùng JWT của tài khoản
/// hiện tại để backend kiểm tra người xem có thuộc booking không.
class TrackingMapPage extends StatelessWidget {
  const TrackingMapPage({super.key, required this.target, this.api});

  final TrackingTarget target;
  final TrackingApi? api;

  @override
  Widget build(BuildContext context) {
    return TrackingAuthGate(
      title: 'Bản đồ theo dõi',
      builder: (context, auth) =>
          _TrackingMapView(target: target, api: api, auth: auth),
    );
  }
}

/// Lý do chưa mở được bản đồ, dựa trên `state` backend trả về.
String _statusMessage(TrackingStatus status) => switch (status.state) {
  'Ready' => 'Đang kết nối vị trí GPS của người thuê.',
  'MeetingPointsMissing' =>
    'Chủ xe chưa thiết lập toạ độ điểm nhận/trả xe cho chuyến này.',
  'Inactive' => 'Chỉ có thể theo dõi khi booking ở trạng thái Đang thuê.',
  _ => 'Chưa xem được vị trí cho chuyến này.',
};

class _TrackingMapView extends StatefulWidget {
  const _TrackingMapView({
    required this.target,
    required this.api,
    required this.auth,
  });

  final TrackingTarget target;
  final TrackingApi? api;
  final AuthController auth;

  @override
  State<_TrackingMapView> createState() => _TrackingMapViewState();
}

class _TrackingMapViewState extends State<_TrackingMapView> {
  late final TrackingApi _api = widget.api ?? HttpTrackingApi();
  final MapController _mapController = MapController();
  final RouteService _routeService = RouteService();

  TrackingSnapshot? _snapshot;
  TrackingStatus? _statusGate;
  TrackingApiException? _blockingError;
  String? _error;
  bool _loading = true;
  bool _waitingForPosition = false;

  TrackingHub? _hub;
  TrackingHubState _hubState = TrackingHubState.connecting;
  String? _hubError;
  bool _retryingHub = false;

  bool _mapReady = false;
  bool _fitted = false;
  bool _follow = true;

  DrivingRoute? _route;
  LatLng? _routeFrom;
  LatLng? _routeDestination;
  DateTime? _routeRequestedAt;
  bool _routeLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapReady = true;
      _afterSnapshot();
    });
    unawaited(_loadSnapshot());
  }

  @override
  void dispose() {
    final hub = _hub;
    _hub = null;
    unawaited(hub?.disconnect());
    _routeService.close();
    _mapController.dispose();
    if (widget.api == null && _api is HttpTrackingApi) {
      _api.close();
    }
    super.dispose();
  }

  Future<void> _loadSnapshot({bool retried = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _blockingError = null;
      _statusGate = null;
    });

    final token = await widget.auth.validAccessToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      await widget.auth.logout();
      return;
    }

    // Hỏi trạng thái trước: nếu chưa tới giờ hoặc thiếu cấu hình thì báo lý do
    // kèm đếm ngược thay vì gọi snapshot để nhận lỗi 409/503.
    final gate = await _loadStatusGate(token);
    if (!mounted) return;
    if (gate != null) {
      setState(() {
        _loading = false;
        _waitingForPosition = false;
        _statusGate = gate;
      });
      return;
    }

    try {
      final snapshot = await _api.getSnapshot(widget.target.bookingId, token);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _waitingForPosition = false;
        _blockingError = null;
        _error = null;
      });
      _applySnapshot(snapshot);
      unawaited(_connectHub());
    } on TrackingApiException catch (error) {
      if (!mounted) return;
      if (error.isSessionExpired) {
        if (!retried && await widget.auth.refreshSession()) {
          return _loadSnapshot(retried: true);
        }
        await widget.auth.logout();
        return;
      }

      setState(() {
        _loading = false;
        if (error.canStillWatchRealtime) {
          _waitingForPosition = true;
          _error = null;
          _blockingError = null;
        } else {
          _blockingError = error;
          _error = null;
        }
      });

      if (error.canStillWatchRealtime) {
        unawaited(_connectHub());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được vị trí xe. Vui lòng thử lại.';
      });
    }
  }

  Future<TrackingStatus?> _loadStatusGate(String token) async {
    try {
      final status = await _api.getStatus(widget.target.bookingId, token);
      return status.canTrack ? null : status;
    } on TrackingApiException {
      // Endpoint không dùng được (lỗi mạng, bản backend cũ…) thì giữ luồng cũ:
      // cứ gọi snapshot và xử lý lỗi như trước.
      return null;
    }
  }

  Future<void> _connectHub() async {
    if (_hub != null || _blockingError != null) return;

    final hub = TrackingHub(
      hubUrl: AppConfig.trackingHubUrl,
      bookingId: widget.target.bookingId,
      accessTokenFactory: () async =>
          await widget.auth.validAccessToken(
            leeway: const Duration(seconds: 30),
          ) ??
          '',
      onPosition: _onPosition,
      onState: (state) {
        if (!mounted) return;
        setState(() {
          _hubState = state;
          if (state == TrackingHubState.connected) _hubError = null;
        });
      },
    );
    _hub = hub;

    try {
      await hub.connect();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hubState = TrackingHubState.disconnected;
        _hubError =
            'Không kết nối được realtime. Bản đồ vẫn hiển thị vị trí mới nhất.';
      });
    }
  }

  void _onPosition(TrackingSnapshot update) {
    if (!mounted) return;
    setState(() {
      _waitingForPosition = false;
      _hubError = null;
    });
    _applySnapshot(update);
  }

  void _applySnapshot(TrackingSnapshot next) {
    if (!mounted) return;
    final current = _snapshot;
    if (current != null && next.recordedAt.isBefore(current.recordedAt)) {
      return;
    }

    final destinationChanged =
        current == null ||
        (current.destinationLatitude - next.destinationLatitude).abs() >
            0.000001 ||
        (current.destinationLongitude - next.destinationLongitude).abs() >
            0.000001;

    setState(() {
      _snapshot = next;
      _loading = false;
      if (destinationChanged) _route = null;
    });
    _afterSnapshot();
  }

  void _afterSnapshot() {
    final snapshot = _snapshot;
    if (snapshot == null || !_mapReady) return;

    final position = LatLng(snapshot.latitude, snapshot.longitude);
    final destination = LatLng(
      snapshot.destinationLatitude,
      snapshot.destinationLongitude,
    );

    if (!_fitted) {
      _fitted = true;
      fitMapToPoints(_mapController, [position, destination]);
    } else if (_follow) {
      _mapController.move(position, _mapController.camera.zoom);
    }

    unawaited(_maybeLoadRoute(position, destination));
  }

  Future<void> _maybeLoadRoute(LatLng from, LatLng to) async {
    if (_routeLoading) return;

    const distance = Distance();
    final destinationChanged =
        _routeDestination == null ||
        distance.as(LengthUnit.Meter, _routeDestination!, to) > 30;
    final moved = _routeFrom == null
        ? double.infinity
        : distance.as(LengthUnit.Meter, _routeFrom!, from);
    final requestedAt = _routeRequestedAt;
    final stale =
        requestedAt == null ||
        DateTime.now().difference(requestedAt) > const Duration(seconds: 45);

    if (!destinationChanged && !stale && moved < 250) return;

    if (destinationChanged) {
      setState(() => _route = null);
    }

    _routeLoading = true;
    _routeFrom = from;
    _routeDestination = to;
    _routeRequestedAt = DateTime.now();

    final route = await _routeService.drivingRoute(from, to);
    _routeLoading = false;
    if (!mounted || route == null) return;
    setState(() => _route = route);
  }

  Future<void> _retryHub() async {
    if (_retryingHub) return;
    setState(() {
      _retryingHub = true;
      _hubError = null;
      _hubState = TrackingHubState.connecting;
    });

    final hub = _hub;
    _hub = null;
    await hub?.disconnect();

    if (mounted) setState(() => _retryingHub = false);
    await _connectHub();
  }

  void _recenter() {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    setState(() => _follow = true);
    if (!_mapReady) return;
    _mapController.move(LatLng(snapshot.latitude, snapshot.longitude), 15.5);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final email = widget.auth.account?.email ?? '';

    if (_statusGate != null) {
      return _UnavailableView(
        target: widget.target,
        message: _statusMessage(_statusGate!),
        email: email,
        onRetry: _loadSnapshot,
      );
    }

    if (_blockingError != null) {
      return _UnavailableView(
        target: widget.target,
        message: _blockingError!.displayMessage,
        email: email,
        onRetry: _loadSnapshot,
      );
    }

    final center = snapshot == null
        ? const LatLng(AppConfig.defaultLatitude, AppConfig.defaultLongitude)
        : LatLng(snapshot.latitude, snapshot.longitude);

    final position = snapshot == null
        ? null
        : LatLng(snapshot.latitude, snapshot.longitude);
    final destination = snapshot == null
        ? null
        : LatLng(snapshot.destinationLatitude, snapshot.destinationLongitude);

    final markers = <Marker>[
      if (position != null) vehicleMarker(position),
      if (destination != null)
        destinationMarker(
          destination,
          label: 'Điểm trả xe',
        ),
    ];

    final polylines = <Polyline>[
      if (_route != null)
        routePolyline(_route!.points)
      else if (position != null && destination != null)
        directPolyline(position, destination),
    ];

    final routeMatches =
        _routeDestination != null &&
        destination != null &&
        const Distance().as(LengthUnit.Meter, _routeDestination!, destination) <
            50;
    final eta = snapshot == null
        ? null
        : (_route != null && routeMatches && _route!.duration.inSeconds > 0
              ? _route!.duration
              : estimateDuration(snapshot.distanceMeters));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.target.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            if (email.isNotEmpty)
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.textDim),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadSnapshot,
            tooltip: 'Cập nhật vị trí',
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
      body: Stack(
        children: [
          TrackingMapView(
            controller: _mapController,
            center: center,
            zoom: 14,
            markers: markers,
            polylines: polylines,
          ),
          if (_loading && snapshot == null)
            const ColoredBox(
              color: Color(0x660F172A),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primarySoft),
              ),
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: TrackingErrorBanner(message: _error!),
                  ),
                if (_hubError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _HubErrorBanner(
                      message: _hubError!,
                      onRetry: _retryingHub ? null : _retryHub,
                    ),
                  ),
                if (snapshot != null && snapshot.arrived)
                  const _ArrivedBanner(),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 10),
                    child: FloatingActionButton.small(
                      heroTag: 'tracking-follow',
                      backgroundColor: AppColors.surface,
                      foregroundColor: _follow
                          ? AppColors.primarySoft
                          : AppColors.textMuted,
                      onPressed: snapshot == null
                          ? null
                          : () {
                              if (_follow) {
                                setState(() => _follow = false);
                              } else {
                                _recenter();
                              }
                            },
                      child: Icon(
                        _follow
                            ? Icons.gps_fixed_rounded
                            : Icons.gps_not_fixed_rounded,
                      ),
                    ),
                  ),
                ),
                TrackingPanel(
                  child: _TrackingSummary(
                    snapshot: snapshot,
                    target: widget.target,
                    hubState: _hubState,
                    email: email,
                    eta: eta,
                    waiting: _waitingForPosition,
                    onRetry: _loadSnapshot,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingSummary extends StatelessWidget {
  const _TrackingSummary({
    required this.snapshot,
    required this.target,
    required this.hubState,
    required this.email,
    required this.eta,
    required this.waiting,
    required this.onRetry,
  });

  final TrackingSnapshot? snapshot;
  final TrackingTarget target;
  final TrackingHubState hubState;
  final String email;
  final Duration? eta;
  final bool waiting;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final stage = snapshot?.stage;
    final stageLabel = stage?.label ?? 'Đang chờ vị trí xe';
    final viewerLabel = stage?.viewerLabel ?? 'Chưa xác định giai đoạn';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TrackingHubBadge(state: hubState),
            const Spacer(),
            if (snapshot != null)
              LiveAgeText(
                time: snapshot!.recordedAt,
                style: const TextStyle(fontSize: 11, color: AppColors.textDim),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                stage == TrackingStage.returnTrip
                    ? Icons.flag_rounded
                    : Icons.near_me_rounded,
                size: 18,
                color: AppColors.primarySoft,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stageLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$viewerLabel · ${target.vehicleName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (target.status != null && target.status!.isNotEmpty) ...[
          const SizedBox(height: 8),
          BookingStatusBadge(status: target.status!),
        ],
        const Divider(color: AppColors.border, height: 18),
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Còn cách',
                value: snapshot == null
                    ? '—'
                    : formatDistance(snapshot!.distanceMeters),
              ),
            ),
            Expanded(
              child: _Stat(
                label: 'Dự kiến',
                value: eta == null ? '—' : formatDuration(eta!),
              ),
            ),
            Expanded(
              child: _Stat(
                label: 'Cập nhật',
                value: snapshot == null
                    ? '—'
                    : formatRelativeTime(snapshot!.recordedAt),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TrackingInfoRow(
          icon: Icons.person_rounded,
          label: 'Tài khoản xem',
          value: email.isEmpty ? 'Đã đăng nhập' : email,
        ),
        TrackingInfoRow(
          icon: Icons.confirmation_number_rounded,
          label: 'Booking',
          value: target.shortCode,
        ),
        if (snapshot?.accuracyMeters != null)
          TrackingInfoRow(
            icon: Icons.my_location_rounded,
            label: 'Sai số GPS',
            value: '±${snapshot!.accuracyMeters!.round()} m',
          ),
        if (waiting || snapshot == null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primarySoft,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Đang chờ thiết bị GPS trên xe gửi vị trí...',
                  style: TextStyle(fontSize: 11, color: AppColors.textDim),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text('Thử lại', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
        if (snapshot != null && !waiting) ...[
          const SizedBox(height: 4),
          const Text(
            'Vị trí và khoảng cách do backend tính từ GPS Traccar của xe.',
            style: TextStyle(fontSize: 10, color: AppColors.textDim),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textDim),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _ArrivedBanner extends StatelessWidget {
  const _ArrivedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF052E16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF166534)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF4ADE80)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Xe đã tới điểm hẹn (trong phạm vi 30 m).',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF86EFAC),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubErrorBanner extends StatelessWidget {
  const _HubErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3B2A05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF854D0E)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: Color(0xFFFBBF24),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Color(0xFFFDE68A),
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Kết nối lại', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _UnavailableView extends StatelessWidget {
  const _UnavailableView({
    required this.target,
    required this.message,
    required this.email,
    required this.onRetry,
  });

  final TrackingTarget target;
  final String message;
  final String email;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Bản đồ theo dõi'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_off_rounded,
                      color: AppColors.primarySoft,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Chưa xem được vị trí',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mã booking: ${target.shortCode}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textDim,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tài khoản: $email',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Tải lại vị trí'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
