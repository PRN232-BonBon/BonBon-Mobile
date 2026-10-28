# BonBon Mobile

Bản mobile (Flutter) của `BonBon-Frontend` — cùng luồng đăng nhập/đăng ký,
cùng các endpoint `/api/auth/*` và cùng bảng màu với bản web.

## Chức năng

- Đăng nhập bằng email + mật khẩu (gửi kèm `deviceInfo`).
- Đăng nhập bằng Google (`google_sign_in` → `idToken` → `/google-login`).
- Đăng ký tài khoản (họ tên, email, mật khẩu, xác nhận, tên hiển thị, SĐT).
- Dashboard: thông tin tài khoản, role, token info (xem/ẩn token).
- Đăng xuất và đăng xuất tất cả thiết bị.
- Phiên đăng nhập được lưu lại giữa các lần mở app (SharedPreferences, key
  `bb_access` / `bb_refresh` / `bb_account` giống bản web).

## Cấu trúc

```
lib/
  app.dart                  # tương đương App.tsx (AuthProvider + router)
  config/app_config.dart    # API_BASE_URL, Google client ID từ --dart-define
  models/auth.dart          # AccountInfo, AuthResponse, request, ApiException
  services/auth_api.dart    # gọi /api/auth/*, tự gắn Bearer token
  services/token_store.dart # lưu phiên (thay cho localStorage)
  services/google_auth.dart # bọc google_sign_in 7.x
  state/auth_controller.dart# tương đương AuthContext
  state/auth_scope.dart     # tương đương useAuth()
  pages/                    # LoginPage, RegisterPage, DashboardPage, AuthGate
  theme/                    # màu + theme tối theo bản web
  widgets/common.dart       # logo, banner lỗi, input, nút, card
```

## Chạy

```bash
flutter pub get

# Android emulator (10.0.2.2 là localhost của máy dev)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5188/api
```

- Điện thoại thật: trỏ tới IP LAN của máy chạy backend, ví dụ
  `--dart-define=API_BASE_URL=http://192.168.1.20:5188/api`.
- Backend chỉ mở HTTPS (vd. `https://localhost:7124`): dùng
  `--dart-define=API_BASE_URL=https://10.0.2.2:7124/api`; với cert tự ký của
  `dotnet dev-certs` cần cài cert tin cậy trên thiết bị/emulator.
- Nếu không truyền gì, app dùng mặc định `http://10.0.2.2:5188/api`.

### Google Sign-In

1. Trên Google Cloud Console tạo **OAuth client ID → Web application** (dùng làm
   `serverClientId`) và **Android** (package `com.example.bonbon_mobile` + SHA-1
   của keystore đang build).
2. Chạy:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:5188/api \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

Khi chưa cấu hình client ID, nút Google được ẩn — giống bản web khi
`VITE_GOOGLE_CLIENT_ID` để trống. Với iOS/macOS truyền thêm
`--dart-define=GOOGLE_CLIENT_ID=<ios-client-id>`.

## Kiểm tra

```bash
flutter analyze
flutter test
```
