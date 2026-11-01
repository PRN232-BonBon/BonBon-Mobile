import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import 'tracking_models.dart';

enum TrackingHubState { connecting, connected, reconnecting, disconnected }

/// Kết nối `/hubs/tracking` của backend.
///
/// Backend xác thực JWT, kiểm tra tài khoản có thuộc booking không rồi mới cho
/// join group và phát `PositionUpdated`.
class TrackingHub {
  TrackingHub({
    required this.hubUrl,
    required this.bookingId,
    required this.accessTokenFactory,
    this.onPosition,
    this.onState,
  });

  final String hubUrl;
  final String bookingId;
  final Future<String> Function() accessTokenFactory;
  final void Function(TrackingSnapshot position)? onPosition;
  final void Function(TrackingHubState state)? onState;

  HubConnection? _connection;
  bool _closed = false;

  Future<void> connect() async {
    final connection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: accessTokenFactory,
            transport: HttpTransportType.WebSockets,
            requestTimeout: 15000,
          ),
        )
        .withAutomaticReconnect(
          retryDelays: const [0, 2000, 5000, 10000, 30000],
        )
        .build();

    _connection = connection;
    connection.on('PositionUpdated', _handlePositionUpdated);
    connection.onreconnecting(({error}) {
      if (!_closed) onState?.call(TrackingHubState.reconnecting);
    });
    connection.onreconnected(({connectionId}) async {
      if (_closed) return;
      try {
        await _join();
        onState?.call(TrackingHubState.connected);
      } catch (_) {
        onState?.call(TrackingHubState.disconnected);
        await connection.stop();
      }
    });
    connection.onclose(({error}) {
      if (!_closed) onState?.call(TrackingHubState.disconnected);
    });

    onState?.call(TrackingHubState.connecting);
    await connection.start();
    await _join();
    onState?.call(TrackingHubState.connected);
  }

  Future<void> _join() =>
      _connection?.invoke('JoinBooking', args: <Object>[bookingId]) ??
      Future<void>.value();

  void _handlePositionUpdated(List<Object?>? arguments) {
    if (_closed || arguments == null || arguments.isEmpty) return;
    final raw = arguments.first;
    if (raw is! Map) return;

    final update = TrackingSnapshot.fromJson(raw.cast<String, dynamic>());
    if (update.bookingId.toLowerCase() != bookingId.toLowerCase()) return;
    onPosition?.call(update);
  }

  Future<void> disconnect() async {
    if (_closed) return;
    _closed = true;
    final connection = _connection;
    _connection = null;
    if (connection == null) return;

    try {
      await connection.invoke('LeaveBooking', args: <Object>[bookingId]);
    } catch (_) {
      // Có thể mất mạng; vẫn đóng socket bên dưới.
    }
    try {
      await connection.stop();
    } catch (_) {
      // Socket đã đóng.
    }
  }
}
