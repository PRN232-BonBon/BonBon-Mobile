import 'package:flutter/foundation.dart';

/// Cấu hình build-time, truyền vào qua `--dart-define`.
///
/// Ví dụ chạy trên Android emulator:
/// ```
/// flutter run \
///   --dart-define=API_BASE_URL=http://10.0.2.2:5188/api \
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
/// ```
class AppConfig {
  const AppConfig._();

  /// Base URL của backend, đã bao gồm `/api` nhưng chưa có `/auth`.
  /// Android emulator dùng alias 10.0.2.2; desktop/iOS simulator dùng localhost.
  /// Điện thoại Android thật cần truyền IP LAN qua API_BASE_URL.
  static const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');
  static String get apiBaseUrl => _apiBaseUrlOverride.isNotEmpty
      ? _apiBaseUrlOverride
      : defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:5188/api'
          : 'http://localhost:5188/api';

  /// Google **Web** client ID, dùng làm `serverClientId` trên Android
  /// để Google trả về `idToken`.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Google client ID cho iOS/macOS (nếu build cho các nền tảng đó).
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  /// Chỉ hiện nút "Đăng nhập bằng Google" khi đã cấu hình client ID,
  /// giống frontend web khi `VITE_GOOGLE_CLIENT_ID` để trống.
  static bool get isGoogleConfigured =>
      googleServerClientId.isNotEmpty || googleClientId.isNotEmpty;

  /// URL hub SignalR của backend. Mặc định suy ra từ [apiBaseUrl]:
  /// `http://10.0.2.2:5188/api` → `http://10.0.2.2:5188/hubs/tracking`.
  static const String trackingHubUrlOverride = String.fromEnvironment(
    'TRACKING_HUB_URL',
  );

  static String get trackingHubUrl {
    if (trackingHubUrlOverride.isNotEmpty) return trackingHubUrlOverride;
    final base = apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return '${base.replaceFirst(RegExp(r'/$'), '')}/hubs/tracking';
  }

  /// Tile server của bản đồ. Mặc định dùng CARTO Dark (dữ liệu OSM) nên không
  /// cần API key và hợp với theme tối của app.
  static const String mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
  );

  /// Tâm bản đồ mặc định khi chưa có vị trí nào (TP. Hồ Chí Minh).
  static const double defaultLatitude = 10.7769;
  static const double defaultLongitude = 106.7009;
}
