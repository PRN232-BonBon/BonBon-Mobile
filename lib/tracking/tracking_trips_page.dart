import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/auth.dart';
import '../state/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'tracking_api.dart';
import 'tracking_auth_gate.dart';
import 'tracking_map_page.dart';
import 'tracking_models.dart';
import 'tracking_widgets.dart';

/// Danh sách chuyến của tài khoản đang đăng nhập và lối vào bản đồ tracking.
class TrackingTripsPage extends StatelessWidget {
  const TrackingTripsPage({super.key, this.api});

  final TrackingApi? api;

  @override
  Widget build(BuildContext context) {
    return TrackingAuthGate(
      builder: (context, auth) => _TripsView(api: api, auth: auth),
    );
  }
}

class _TripsView extends StatefulWidget {
  const _TripsView({required this.api, required this.auth});

  final TrackingApi? api;
  final AuthController auth;

  @override
  State<_TripsView> createState() => _TripsViewState();
}

class _TripsViewState extends State<_TripsView> {
  late final TrackingApi _api = widget.api ?? HttpTrackingApi();

  List<CustomerBooking>? _bookings;
  List<OwnerBooking> _ownerBookings = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void dispose() {
    if (widget.api == null && _api is HttpTrackingApi) {
      _api.close();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bookings = await _fetchBookings();
      final ownerBookings = widget.auth.account?.roles.contains('VehicleOwner') == true
          ? await _fetchOwnerBookings() : const <OwnerBooking>[];
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _ownerBookings = ownerBookings;
        _loading = false;
      });
    } on TrackingApiException catch (error) {
      if (error.isSessionExpired) {
        await widget.auth.logout();
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = error.displayMessage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải danh sách chuyến. Vui lòng thử lại.';
        _loading = false;
      });
    }
  }

  Future<List<CustomerBooking>> _fetchBookings() async {
    var token = await widget.auth.validAccessToken();
    if (token == null || token.isEmpty) {
      throw const TrackingApiException(
        statusCode: 401,
        code: 'UNAUTHENTICATED',
        message: 'Phiên đăng nhập không còn hiệu lực.',
      );
    }

    try {
      return await _api.getMyBookings(token);
    } on TrackingApiException catch (error) {
      if (!error.isSessionExpired) rethrow;
      // Access token có thể vừa hết hạn: refresh một lần rồi thử lại.
      if (!await widget.auth.refreshSession()) rethrow;
      final refreshedToken = widget.auth.accessToken;
      if (refreshedToken == null || refreshedToken.isEmpty) rethrow;
      return _api.getMyBookings(refreshedToken);
    }
  }

  Future<List<OwnerBooking>> _fetchOwnerBookings() async {
    final token = await widget.auth.validAccessToken();
    if (token == null || token.isEmpty) return const [];
    return _api.getOwnerBookings(token);
  }

  void _openMap(TrackingTarget target) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrackingMapPage(target: target, api: _api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.auth.account;
    final bookings = _bookings;
    final isOwner = account?.roles.contains('VehicleOwner') == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Theo dõi chuyến đi'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primarySoft,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _ViewerCard(account: account),
            const SizedBox(height: 16),
            if (_error != null) ...[
              TrackingErrorBanner(message: _error!),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Thử lại'),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_loading && bookings == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primarySoft,
                  ),
                ),
              )
            else if (bookings == null || bookings.isEmpty)
              _EmptyTrips(isOwner: isOwner)
            else ...[
              const _SectionTitle('Chuyến thuê của bạn'),
              const SizedBox(height: 10),
              for (final booking in bookings) ...[
                _BookingCard(
                  booking: booking,
                  onTrack: booking.canTrackPickup
                      ? () => _openMap(booking.target)
                      : null,
                ),
                if (booking.canShareLiveLocation) ...[
                  const SizedBox(height: 8),
                  _CustomerGpsSharing(booking: booking, auth: widget.auth, api: _api),
                ],
                const SizedBox(height: 12),
              ],
            ],
            if (isOwner) ...[
              const SizedBox(height: 8),
              const _SectionTitle('Xe của bạn đang được thuê'),
              const SizedBox(height: 10),
              if (_ownerBookings.isEmpty)
                const Text('Chưa có booking thuê xe của bạn.', style: TextStyle(color: AppColors.textDim))
              else for (final booking in _ownerBookings.where((b) => b.canTrack)) ...[
                _OwnerBookingCard(booking: booking, onOpen: () => _openMap(booking.target)),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 16),
            const _FootNote(),
          ],
        ),
      ),
    );
  }
}

class _ViewerCard extends StatelessWidget {
  const _ViewerCard({required this.account});

  final AccountInfo? account;

  @override
  Widget build(BuildContext context) {
    final name = account?.fullName ?? 'Tài khoản BonBon';
    final email = account?.email ?? '';
    final roleLabel = account?.roles.contains('VehicleOwner') == true
        ? 'Chủ xe'
        : 'Người thuê';

    return CardSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: AppColors.primarySoft,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang xem với $roleLabel · $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email.isEmpty
                      ? 'Tài khoản này được backend dùng để xác định quyền xem.'
                      : '$email · backend xác định quyền xem theo tài khoản này.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: AppColors.textDim,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onTrack});

  final CustomerBooking booking;
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveMediaUrl(booking.coverImageUrl);

    return CardSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrl == null
                    ? _CoverFallback()
                    : Image.network(
                        imageUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _CoverFallback(),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.vehicleName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking.plateNumber,
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.6,
                        color: AppColors.token,
                      ),
                    ),
                    const SizedBox(height: 6),
                    BookingStatusBadge(status: booking.status),
                  ],
                ),
              ),
              Text(
                formatMoney(booking.totalAmount, booking.currency),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.textDim,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  formatBookingWindow(booking.startAt, booking.endAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                rentalTypeLabel(booking.rentalType),
                style: const TextStyle(fontSize: 11, color: AppColors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bookingStatusHint(booking),
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: AppColors.textDim,
            ),
          ),
          if (onTrack != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTrack,
                icon: const Icon(Icons.near_me_rounded, size: 17),
                label: const Text('Theo dõi xe tới điểm lấy'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      color: AppColors.background,
      child: const Icon(
        Icons.directions_car_filled_rounded,
        color: AppColors.textDim,
        size: 26,
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips({required this.isOwner});

  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        children: [
          const Icon(Icons.route_rounded, size: 38, color: AppColors.textDim),
          const SizedBox(height: 10),
          const Text(
            'Chưa có chuyến thuê nào',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isOwner
                ? 'Các booking đang thuê sẽ xuất hiện ở mục theo dõi xe của bạn bên dưới.'
                : 'Khi bạn đặt xe, chuyến thuê sẽ xuất hiện ở đây để theo dõi '
                      'xe tới điểm lấy.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerBookingCard extends StatelessWidget {
  const _OwnerBookingCard({required this.booking, required this.onOpen});
  final OwnerBooking booking;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => CardSurface(
    padding: const EdgeInsets.all(14),
    child: Row(children: [
      const Icon(Icons.directions_car_filled_rounded, color: AppColors.primarySoft),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${booking.vehicleName} · ${booking.plateNumber}', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        Text('Người thuê: ${booking.customerName} · Đang thuê', style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
      ])),
      IconButton(onPressed: onOpen, icon: const Icon(Icons.map_rounded, color: AppColors.primarySoft), tooltip: 'Theo dõi trên bản đồ'),
    ]),
  );
}

class _CustomerGpsSharing extends StatefulWidget {
  const _CustomerGpsSharing({required this.booking, required this.auth, required this.api});
  final CustomerBooking booking;
  final AuthController auth;
  final TrackingApi api;
  @override
  State<_CustomerGpsSharing> createState() => _CustomerGpsSharingState();
}

class _CustomerGpsSharingState extends State<_CustomerGpsSharing> {
  StreamSubscription<Position>? _subscription;
  bool _sharing = false;
  String? _message;
  @override
  void dispose() { _subscription?.cancel(); super.dispose(); }

  Future<void> _toggle() async {
    if (_sharing) {
      await _subscription?.cancel();
      if (mounted) setState(() { _sharing = false; _message = 'Đã dừng chia sẻ vị trí.'; });
      return;
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('Hãy bật GPS trên điện thoại.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('BonBon cần quyền vị trí để gửi GPS trong thời gian thuê.');
      }
      final token = await widget.auth.validAccessToken();
      if (token == null || token.isEmpty) throw Exception('Phiên đăng nhập hết hạn.');
      final LocationSettings settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 15,
              intervalDuration: const Duration(seconds: 10),
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'BonBon đang chia sẻ vị trí',
                notificationText: 'Vị trí GPS chỉ được gửi trong chuyến thuê đang diễn ra.',
                enableWakeLock: true,
                setOngoing: true,
              ),
            )
          : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15);
      _subscription = Geolocator.getPositionStream(locationSettings: settings).listen((position) async {
        try {
          final accessToken = await widget.auth.validAccessToken();
          if (accessToken == null || accessToken.isEmpty) return;
          await widget.api.reportPosition(widget.booking.bookingId, accessToken,
            latitude: position.latitude, longitude: position.longitude,
            accuracyMeters: position.accuracy, recordedAt: position.timestamp);
          if (mounted) setState(() => _message = 'Đang chia sẻ vị trí GPS với chủ xe.');
        } on TrackingApiException catch (error) {
          if (mounted) setState(() => _message = error.displayMessage);
          if (error.isTrackingNotActive) {
            await _subscription?.cancel();
            if (mounted) setState(() => _sharing = false);
          }
        } catch (_) {
          if (mounted) setState(() => _message = 'Không gửi được vị trí. Kiểm tra kết nối mạng.');
        }
      }, onError: (Object error) { if (mounted) setState(() => _message = 'Không đọc được GPS. Kiểm tra quyền vị trí.'); });
      if (mounted) setState(() { _sharing = true; _message = 'Đang bật GPS, vị trí sẽ gửi khi có tín hiệu.'; });
    } catch (error) {
      if (mounted) setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => CardSurface(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Row(children: [
      Icon(_sharing ? Icons.my_location_rounded : Icons.location_searching_rounded, color: _sharing ? AppColors.primarySoft : AppColors.textDim),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Chia sẻ GPS điện thoại với chủ xe', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 12)),
        Text(_message ?? 'Chỉ hoạt động khi chuyến ở trạng thái Đang thuê.', style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
      ])),
      TextButton(onPressed: _toggle, child: Text(_sharing ? 'Dừng' : 'Bật')),
    ]),
  );
}

class _OwnerTrackingCard extends StatefulWidget {
  const _OwnerTrackingCard({required this.onOpen});

  final void Function(TrackingTarget target) onOpen;

  @override
  State<_OwnerTrackingCard> createState() => _OwnerTrackingCardState();
}

class _OwnerTrackingCardState extends State<_OwnerTrackingCard> {
  static final _guidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    final code = _controller.text.trim();
    if (!_guidPattern.hasMatch(code)) {
      setState(() => _error = 'Mã booking không hợp lệ.');
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    widget.onOpen(TrackingTarget(bookingId: code.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.car_rental_rounded,
                size: 18,
                color: AppColors.primarySoft,
              ),
              SizedBox(width: 8),
              Text(
                'Dành cho chủ xe',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhập mã booking của chuyến đang InProgress để xem người thuê đưa '
            'xe về điểm trả tới đâu. Backend sẽ kiểm tra bạn có phải chủ xe '
            'của chuyến này không.',
            style: TextStyle(
              fontSize: 11,
              height: 1.45,
              color: AppColors.textDim,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F-]')),
              LengthLimitingTextInputFormatter(36),
            ],
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppColors.text,
            ),
            decoration: InputDecoration(
              labelText: 'Mã booking',
              hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
              errorText: _error,
            ),
            onSubmitted: (_) => _open(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _open,
              icon: const Icon(Icons.map_rounded, size: 17),
              label: const Text('Mở bản đồ chiều trả xe'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FootNote extends StatelessWidget {
  const _FootNote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Người thuê chia sẻ GPS từ điện thoại khi booking đang thuê; chủ xe xem '
      'vị trí realtime sau khi đăng nhập. Backend kiểm tra booking và quyền truy cập.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 10, height: 1.45, color: AppColors.textDim),
    );
  }
}
