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
  ///
  /// Mặc định trỏ tới Android emulator (10.0.2.2 = localhost của máy dev),
  /// theo cổng HTTP trong comment của `authService.ts` bên frontend web.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5188/api',
  );

  /// Google **Web** client ID, dùng làm `serverClientId` trên Android
  /// để Google trả về `idToken`.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Google client ID cho iOS/macOS (nếu build cho các nền tảng đó).
  static const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  /// Chỉ hiện nút "Đăng nhập bằng Google" khi đã cấu hình client ID,
  /// giống frontend web khi `VITE_GOOGLE_CLIENT_ID` để trống.
  static bool get isGoogleConfigured =>
      googleServerClientId.isNotEmpty || googleClientId.isNotEmpty;
}
