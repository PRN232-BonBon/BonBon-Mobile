import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tracking_hub.dart';
import 'tracking_models.dart';

class TrackingHubBadge extends StatelessWidget {
  const TrackingHubBadge({super.key, required this.state});

  final TrackingHubState state;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (state) {
      TrackingHubState.connected => (const Color(0xFF22C55E), 'Trực tiếp'),
      TrackingHubState.connecting => (const Color(0xFFF59E0B), 'Đang kết nối'),
      TrackingHubState.reconnecting => (const Color(0xFFF59E0B), 'Kết nối lại'),
      TrackingHubState.disconnected => (AppColors.textDim, 'Mất kết nối'),
    };

    return StatusPill(label: label, color: color);
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 12, color: color)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'ReadyForPickup' => const Color(0xFF22C55E),
      'InProgress' => AppColors.primarySoft,
      'Confirmed' => const Color(0xFF38BDF8),
      'AwaitingPayment' => const Color(0xFFF59E0B),
      'Returned' || 'AwaitingSettlement' => const Color(0xFFA78BFA),
      'Completed' => const Color(0xFF94A3B8),
      'Cancelled' => AppColors.danger,
      _ => AppColors.textMuted,
    };
    return StatusPill(label: bookingStatusLabel(status), color: color);
  }
}

class TrackingInfoRow extends StatelessWidget {
  const TrackingInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textDim),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textDim),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveAgeText extends StatefulWidget {
  const LiveAgeText({
    super.key,
    required this.time,
    this.style,
    this.prefix = 'Cập nhật ',
  });

  final DateTime time;
  final TextStyle? style;
  final String prefix;

  @override
  State<LiveAgeText> createState() => _LiveAgeTextState();
}

class _LiveAgeTextState extends State<LiveAgeText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.prefix}${formatRelativeTime(widget.time)}',
      style:
          widget.style ??
          const TextStyle(fontSize: 12, color: AppColors.textDim),
    );
  }
}

class TrackingPanel extends StatelessWidget {
  const TrackingPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.fromLTRB(12, 0, 12, 12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x77000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class TrackingErrorBanner extends StatelessWidget {
  const TrackingErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerSurface,
        border: Border.all(color: AppColors.dangerBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.dangerText, fontSize: 12),
      ),
    );
  }
}
