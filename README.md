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
- Theo dõi chuyến đi bằng dữ liệu thật của backend: snapshot qua REST và vị trí
  realtime qua SignalR `/hubs/tracking`.

## Theo dõi chuyến đi

App **chỉ xem** vị trí, không phát GPS. Vị trí do thiết bị Traccar Client trên
xe gửi lên Traccar Server; backend `TraccarTrackingWorker` đọc lại, lưu vào
`bonbon.vehicle_location` và phát sự kiện `PositionUpdated` qua SignalR.

Luồng này bám đúng `TrackingService` / `TrackingController` / `TrackingHub` của
backend:

| Ai xem | Xem được khi | Điểm đích |
| --- | --- | --- |
| Người thuê (Customer) | Booking `ReadyForPickup` | Điểm lấy xe |
| Chủ xe (VehicleOwner) | Booking `InProgress` | Điểm trả xe |

- **Bắt buộc đăng nhập** trước khi mở danh sách chuyến hoặc bản đồ. JWT của tài
  khoản hiện tại được gửi kèm cả REST và SignalR; backend dùng nó để xác định
  người xem có thuộc booking hay không. Khi chưa đăng nhập, app hiện màn hình
  yêu cầu đăng nhập thay vì mở bản đồ.
- Danh sách chuyến lấy từ `GET /api/bookings/mine`. Nút theo dõi pickup xuất
  hiện khi chuyến ở `ReadyForPickup`.
- Chủ xe chưa có endpoint "chuyến của tôi", nên màn hình có ô nhập **mã
  booking** (GUID). Backend vẫn kiểm tra tài khoản có phải chủ xe của chuyến
  không trước khi trả snapshot/cho join group.
- Bản đồ gọi `GET /api/bookings/{id}/tracking/snapshot`, sau đó join group
  SignalR `booking:{id}` và cập nhật khi có `PositionUpdated`.
- Nếu snapshot trả `POSITION_NOT_AVAILABLE` (503), app vẫn kết nối SignalR và
  hiện trạng thái "đang chờ thiết bị GPS gửi vị trí".
- Khi access token hết hạn, app refresh một lần rồi thử lại; refresh thất bại
  thì đăng xuất và quay về màn hình đăng nhập.

### Cấu hình

Backend cần cấu hình `Traccar:BaseUrl`, `Traccar:ApiToken`, chủ xe cần gắn
`deviceId` Traccar và thiết lập điểm hẹn cho booking. Mobile không cần thêm
biến môi trường nào ngoài `API_BASE_URL`:

```bash
# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5188/api
```

Hub URL được suy ra từ `API_BASE_URL` (`.../api` → `.../hubs/tracking`). Chỉ khi
backend nằm ở host khác mới cần truyền thêm:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:5188/api \
  --dart-define=TRACKING_HUB_URL=http://10.0.2.2:5188/hubs/tracking
```

## Cấu trúc

```
lib/
  app.dart                    # tương đương App.tsx (AuthProvider + router)
  config/app_config.dart      # API_BASE_URL, hub URL, Google client ID
  models/auth.dart            # AccountInfo, AuthResponse, request, ApiException
  services/auth_api.dart      # gọi /api/auth/*, tự gắn Bearer token
  services/token_store.dart   # lưu phiên (thay cho localStorage)
  services/google_auth.dart   # bọc google_sign_in 7.x
  state/auth_controller.dart  # tương đương AuthContext + refresh token
  state/auth_scope.dart       # tương đương useAuth()
  pages/                      # LoginPage, RegisterPage, DashboardPage, AuthGate
  theme/                      # màu + theme tối theo bản web
  widgets/common.dart         # logo, banner lỗi, input, nút, card
  tracking/
    tracking_auth_gate.dart   # chặn danh sách/bản đồ khi chưa đăng nhập
    tracking_trips_page.dart  # chuyến của tôi + ô mã booking cho chủ xe
    tracking_map_page.dart    # bản đồ snapshot + SignalR realtime
    tracking_api.dart         # REST /bookings/mine, /tracking/snapshot
    tracking_hub.dart         # SignalR client, join/leave booking group
    tracking_models.dart      # snapshot, booking, nhãn trạng thái, định dạng
    tracking_map_view.dart    # tile OSM/CARTO, marker xe/điểm hẹn
    route_service.dart        # tuyến OSRM + ETA
    tracking_widgets.dart     # badge kết nối, panel, thời gian cập nhật
```

## Chạy

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5188/api
```

- Điện thoại thật: trỏ tới IP LAN của máy chạy backend, ví dụ
  `--dart-define=API_BASE_URL=http://192.168.1.20:5188/api`.
- Backend chỉ mở HTTPS (vd. `https://localhost:7124`): dùng
  `--dart-define=API_BASE_URL=https://10.0.2.2:7124/api`; với cert tự ký của
  `dotnet dev-certs` cần cài cert tin cậy trên thiết bị/emulator.

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

Bản đồ dùng tile CARTO Dark (dữ liệu OpenStreetMap, không cần API key) và tuyến
đường OSRM. Đây là các dịch vụ công cộng miễn phí, không có SLA; nếu OSRM lỗi,
app vẫn hiển thị vị trí và khoảng cách do backend tính.
