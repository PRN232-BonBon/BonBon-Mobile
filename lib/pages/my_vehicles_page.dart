import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth.dart';
import '../models/vehicle.dart';
import '../services/vehicle_api.dart';
import '../state/auth_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Xe của chủ xe đang đăng nhập — `GET /api/vehicles/mine`.
class MyVehiclesPage extends StatefulWidget {
  const MyVehiclesPage({super.key, this.api});

  final VehicleApi? api;

  @override
  State<MyVehiclesPage> createState() => _MyVehiclesPageState();
}

class _MyVehiclesPageState extends State<MyVehiclesPage> {
  late final VehicleApi _api = widget.api ?? HttpVehicleApi();

  List<OwnerVehicle>? _vehicles;
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
    if (widget.api == null && _api is HttpVehicleApi) _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = AuthScope.read(context);
      final vehicles = await auth.authorized((token) => _api.getMine(token));
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

  @override
  Widget build(BuildContext context) {
    final vehicles = _vehicles;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Xe của tôi'),
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
                      Icons.garage_rounded,
                      size: 38,
                      color: AppColors.textDim,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Chưa có xe nào',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Xe bạn đăng ký qua backend sẽ hiện ở đây kèm trạng thái '
                      'duyệt.',
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
                _VehicleRow(vehicle: vehicle),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
            const Text(
              'Dữ liệu lấy từ GET /api/vehicles/mine bằng tài khoản đang đăng '
              'nhập.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.45,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({required this.vehicle});

  final OwnerVehicle vehicle;

  static Color _statusColor(String status) => switch (status) {
    'Available' => const Color(0xFF22C55E),
    'Pending' => const Color(0xFFF59E0B),
    'Rejected' => AppColors.danger,
    _ => AppColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(vehicle.status);

    return CardSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  vehicle.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  vehicleStatusLabel(vehicle.status).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.confirmation_number_rounded,
                size: 13,
                color: AppColors.textDim,
              ),
              const SizedBox(width: 5),
              Text(
                vehicle.plateNumber.isEmpty ? 'Chưa có biển số' : vehicle.plateNumber,
                style: const TextStyle(fontSize: 11, color: AppColors.token),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.photo_library_rounded,
                size: 13,
                color: AppColors.textDim,
              ),
              const SizedBox(width: 5),
              Text(
                '${vehicle.imageCount} ảnh',
                style: const TextStyle(fontSize: 11, color: AppColors.textDim),
              ),
            ],
          ),
          if (vehicle.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Lý do từ chối: ${vehicle.rejectionReason}',
              style: const TextStyle(
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
