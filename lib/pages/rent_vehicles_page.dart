import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth.dart';
import '../models/booking.dart';
import '../models/vehicle.dart';
import '../services/booking_api.dart';
import '../services/vehicle_api.dart';
import '../state/auth_scope.dart';
import '../theme/app_theme.dart';
import '../tracking/tracking_api.dart' show resolveMediaUrl;
import '../tracking/tracking_models.dart';
import '../tracking/tracking_trips_page.dart';
import '../widgets/common.dart';

/// Danh mục xe đang cho thuê — `GET /api/vehicles`.
class RentVehiclesPage extends StatefulWidget {
  const RentVehiclesPage({super.key, this.vehicleApi, this.bookingApi});

  final VehicleApi? vehicleApi;
  final BookingApi? bookingApi;

  @override
  State<RentVehiclesPage> createState() => _RentVehiclesPageState();
}

class _RentVehiclesPageState extends State<RentVehiclesPage> {
  late final VehicleApi _api = widget.vehicleApi ?? HttpVehicleApi();

  List<VehicleSummary>? _vehicles;
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
    if (widget.vehicleApi == null && _api is HttpVehicleApi) _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final vehicles = await _api.getCatalog();
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'Không tải được danh sách xe. Vui lòng thử lại.';
        _loading = false;
      });
    }
  }

  void _open(VehicleSummary vehicle) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            VehicleBookingPage(vehicle: vehicle, bookingApi: widget.bookingApi),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = _vehicles;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Thuê xe'),
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
            if (_error != null) ErrorBanner(message: _error!),
            if (_loading && vehicles == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primarySoft,
                  ),
                ),
              )
            else if (vehicles == null || vehicles.isEmpty)
              const CardSurface(
                padding: EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: Column(
                  children: [
                    Icon(
                      Icons.no_crash_rounded,
                      size: 38,
                      color: AppColors.textDim,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Chưa có xe nào đang cho thuê',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Xe đã được duyệt sẽ xuất hiện ở đây để bạn chọn và '
                      'đặt chuyến.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final vehicle in vehicles) ...[
                _VehicleCard(vehicle: vehicle, onSelect: () => _open(vehicle)),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.onSelect});

  final VehicleSummary vehicle;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveMediaUrl(vehicle.imageUrl);

    return CardSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl == null
                ? const _CoverFallback()
                : Image.network(
                    imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _CoverFallback(),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${vehicle.year} · ${vehicle.bodyType} · '
                      '${vehicle.seats} chỗ · ${vehicle.transmission}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${formatMoney(vehicle.dayPrice, 'VND')}/ngày',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    '${formatMoney(vehicle.hourPrice, 'VND')}/giờ',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.place_rounded,
                size: 13,
                color: AppColors.textDim,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  vehicle.pickupAddress.isEmpty
                      ? 'Chưa cập nhật điểm lấy xe'
                      : vehicle.pickupAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSelect,
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text('Chọn xe và tính giá'),
            ),
          ),
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
      height: 150,
      width: double.infinity,
      color: AppColors.background,
      child: const Icon(
        Icons.directions_car_filled_rounded,
        color: AppColors.textDim,
        size: 32,
      ),
    );
  }
}

/// Chọn thời gian thuê và gọi quote/availability/create.
class VehicleBookingPage extends StatefulWidget {
  const VehicleBookingPage({super.key, required this.vehicle, this.bookingApi});

  final VehicleSummary vehicle;
  final BookingApi? bookingApi;

  @override
  State<VehicleBookingPage> createState() => _VehicleBookingPageState();
}

class _VehicleBookingPageState extends State<VehicleBookingPage> {
  late final BookingApi _bookings = widget.bookingApi ?? HttpBookingApi();

  String _rentalType = RentalWindowRequest.daily;
  DateTime _startAt = _defaultStart();
  DateTime _endAt = _defaultStart().add(const Duration(days: 1));
  int _hours = 4;

  RentalWindow? _window;
  BookingQuote? _quote;
  bool _loading = false;
  bool _booking = false;
  String? _error;

  static DateTime _defaultStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 9);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshQuote());
    });
  }

  @override
  void dispose() {
    if (widget.bookingApi == null && _bookings is HttpBookingApi) {
      _bookings.close();
    }
    super.dispose();
  }

  RentalWindowRequest get _request => _rentalType == RentalWindowRequest.hourly
      ? RentalWindowRequest(
          rentalType: RentalWindowRequest.hourly,
          startAt: _startAt,
          endAt: _startAt.add(Duration(hours: _hours)),
        )
      : RentalWindowRequest(
          rentalType: RentalWindowRequest.daily,
          startAt: _startAt,
          endAt: _endAt,
        );

  void _setRentalType(String value) {
    if (value == _rentalType) return;
    setState(() {
      _rentalType = value;
      _window = null;
      _quote = null;
      _error = null;
    });
    unawaited(_refreshQuote());
  }

  void _setHours(int hours) {
    if (hours == _hours) return;
    setState(() {
      _hours = hours;
      _window = null;
      _quote = null;
      _error = null;
    });
    unawaited(_refreshQuote());
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (time == null || !mounted) return;

    final minute = _rentalType == RentalWindowRequest.hourly
        ? (time.minute < 30 ? 0 : 30)
        : time.minute;
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      minute,
    );

    setState(() {
      _startAt = start;
      if (!_endAt.isAfter(start)) {
        _endAt = DateTime(
          start.year,
          start.month,
          start.day + 1,
          start.hour,
          start.minute,
        );
      }
      _window = null;
      _quote = null;
      _error = null;
    });
    unawaited(_refreshQuote());
  }

  Future<void> _pickEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endAt,
      firstDate: _startAt.add(const Duration(days: 1)),
      lastDate: _startAt.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;

    setState(() {
      _endAt = DateTime(
        date.year,
        date.month,
        date.day,
        _startAt.hour,
        _startAt.minute,
      );
      _window = null;
      _quote = null;
      _error = null;
    });
    unawaited(_refreshQuote());
  }

  Future<void> _refreshQuote() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final request = _request;
    try {
      final window = await _bookings.validateWindow(request);
      if (!mounted) return;
      setState(() => _window = window);

      final quote = await _bookings.quote(widget.vehicle.id, request);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _quote = null;
        _window = null;
        _loading = false;
        _error = _messageFor(error);
      });
    }
  }

  Future<void> _book() async {
    final quote = _quote;
    if (quote == null || !quote.isAvailable) return;

    setState(() {
      _booking = true;
      _error = null;
    });

    final request = _request;
    final auth = AuthScope.read(context);
    try {
      final available = await _bookings.isAvailable(widget.vehicle.id, request);
      if (!available) {
        throw const ApiException(
          title: 'SCHEDULE_CONFLICT',
          detail: 'Xe đã có lịch trong khoảng thời gian này.',
        );
      }

      final created = await auth.authorized(
        (token) => _bookings.create(widget.vehicle.id, request, token),
      );

      if (!mounted) return;
      setState(() => _booking = false);
      await _showCreated(created);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _booking = false;
        _error = _messageFor(error);
      });
    }
  }

  Future<void> _showCreated(CreatedBooking created) async {
    final openTrips = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF22C55E),
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Đã tạo chuyến thuê',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mã booking ${created.shortCode} · '
                '${formatMoney(created.quotedRentalAmount, created.currency)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatBookingWindow(created.startAt, created.endAt),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDim,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Xem chuyến của tôi'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (openTrips == true) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const TrackingTripsPage()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  String _messageFor(Object error) => error is ApiException
      ? error.message
      : 'Không thể hoàn tất. Vui lòng thử lại.';

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final quote = _quote;
    final imageUrl = resolveMediaUrl(vehicle.imageUrl);

    return PageScaffold(
      maxWidth: 680,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${vehicle.year} · ${vehicle.bodyType} · '
                      '${vehicle.seats} chỗ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Đóng',
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          if (imageUrl != null) const SizedBox(height: 12),
          CardSurface(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.place_rounded,
                  label: 'Điểm lấy xe',
                  value: vehicle.pickupAddress.isEmpty
                      ? 'Chưa cập nhật'
                      : vehicle.pickupAddress,
                ),
                _InfoRow(
                  icon: Icons.settings_rounded,
                  label: 'Hộp số / Nhiên liệu',
                  value: '${vehicle.transmission} · ${vehicle.fuel}',
                ),
                _InfoRow(
                  icon: Icons.payments_rounded,
                  label: 'Giá thuê',
                  value:
                      '${formatMoney(vehicle.dayPrice, 'VND')}/ngày · '
                      '${formatMoney(vehicle.hourPrice, 'VND')}/giờ',
                ),
                if (vehicle.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    vehicle.description,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Hình thức thuê'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _Choice(
                label: 'Theo ngày',
                selected: _rentalType == RentalWindowRequest.daily,
                onTap: () => _setRentalType(RentalWindowRequest.daily),
              ),
              _Choice(
                label: 'Theo giờ',
                selected: _rentalType == RentalWindowRequest.hourly,
                onTap: () => _setRentalType(RentalWindowRequest.hourly),
              ),
            ],
          ),
          if (_rentalType == RentalWindowRequest.hourly) ...[
            const SizedBox(height: 14),
            const _SectionTitle('Số giờ thuê'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var hours = 4; hours <= 8; hours++)
                  _Choice(
                    label: '$hours giờ',
                    selected: hours == _hours,
                    onTap: () => _setHours(hours),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const _SectionTitle('Thời gian'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _booking ? null : _pickStart,
            icon: const Icon(Icons.event_rounded, size: 17),
            label: Text('Nhận xe: ${_formatDateTime(_startAt)}'),
          ),
          if (_rentalType == RentalWindowRequest.daily) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _booking ? null : _pickEnd,
              icon: const Icon(Icons.event_available_rounded, size: 17),
              label: Text('Trả xe: ${_formatDateTime(_endAt)}'),
            ),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(
                color: AppColors.primarySoft,
                backgroundColor: AppColors.border,
              ),
            ),
          if (_error != null) ErrorBanner(message: _error!),
          if (quote != null) _QuoteCard(quote: quote, window: _window),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: quote == null || !quote.isAvailable || _booking
                ? null
                : _book,
            child: Text(_booking ? 'Đang đặt xe…' : 'Đặt xe'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Giá và tình trạng còn trống do backend BonBon tính từ cấu hình xe '
            'và lịch đã đặt. Bạn cần đăng nhập để tạo chuyến.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, height: 1.45, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote, required this.window});

  final BookingQuote quote;
  final RentalWindow? window;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Báo giá',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: (quote.isAvailable
                          ? const Color(0xFF22C55E)
                          : AppColors.danger)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  quote.isAvailable ? 'Còn trống' : 'Đã có lịch',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: quote.isAvailable
                        ? const Color(0xFF4ADE80)
                        : AppColors.dangerText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (window != null)
            _PriceRow(
              label: 'Số lượng',
              value: window!.billableLabel,
            ),
          _PriceRow(
            label: 'Đơn giá',
            value: formatMoney(quote.unitPrice, quote.currency),
          ),
          _PriceRow(
            label: 'Tạm tính',
            value: formatMoney(quote.baseRentalAmount, quote.currency),
          ),
          if (quote.discountAmount > 0)
            _PriceRow(
              label: 'Giảm giá tuần (${quote.weeklyDiscountPercent.round()}%)',
              value: '−${formatMoney(quote.discountAmount, quote.currency)}',
            ),
          const Divider(color: AppColors.border, height: 18),
          _PriceRow(
            label: 'Tổng cộng',
            value: formatMoney(quote.quotedRentalAmount, quote.currency),
            highlight: true,
          ),
          if (quote.includedMileageKm != null) ...[
            const SizedBox(height: 6),
            Text(
              'Bao gồm ${quote.includedMileageKm} km'
              '${quote.overageFeePerKm == null ? '' : ' · vượt ${formatMoney(quote.overageFeePerKm!, quote.currency)}/km'}',
              style: const TextStyle(fontSize: 11, color: AppColors.textDim),
            ),
          ],
          if (!quote.isAvailable) ...[
            const SizedBox(height: 8),
            const Text(
              'Xe đã có lịch trong khoảng thời gian này. Hãy chọn thời gian '
              'khác.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.dangerText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: highlight ? 13 : 12,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
                color: highlight ? AppColors.text : AppColors.textMuted,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 14 : 12,
              fontWeight: FontWeight.w700,
              color: highlight ? AppColors.primarySoft : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.text : AppColors.textMuted,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: AppColors.background,
      selectedColor: AppColors.primary.withValues(alpha: 0.22),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textDim),
          const SizedBox(width: 8),
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textDim),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppColors.text),
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

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
