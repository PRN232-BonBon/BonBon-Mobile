// Model tương ứng `src/types/auth.ts` bên frontend web.

class AccountInfo {
  const AccountInfo({
    required this.accountId,
    required this.email,
    required this.fullName,
    this.displayName,
    this.roles = const [],
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    final roles = json['roles'];
    return AccountInfo(
      accountId: (json['accountId'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      displayName: json['displayName'] as String?,
      roles: roles is List
          ? roles.map((role) => role.toString()).toList(growable: false)
          : const [],
    );
  }

  final String accountId;
  final String email;
  final String fullName;
  final String? displayName;
  final List<String> roles;

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'email': email,
    'fullName': fullName,
    'displayName': displayName,
    'roles': roles,
  };
}

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.account,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    accessToken: (json['accessToken'] ?? '').toString(),
    refreshToken: (json['refreshToken'] ?? '').toString(),
    accessTokenExpiresAt: (json['accessTokenExpiresAt'] as num?)?.toInt() ?? 0,
    account: AccountInfo.fromJson(
      (json['account'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  );

  final String accessToken;
  final String refreshToken;
  final int accessTokenExpiresAt;
  final AccountInfo account;
}

class LoginRequest {
  const LoginRequest({
    required this.email,
    required this.password,
    this.deviceInfo,
  });

  final String email;
  final String password;
  final String? deviceInfo;

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    if (deviceInfo != null) 'deviceInfo': deviceInfo,
  };
}

class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.password,
    required this.fullName,
    this.displayName,
    this.phone,
  });

  final String email;
  final String password;
  final String fullName;
  final String? displayName;
  final String? phone;

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'fullName': fullName,
    if (displayName != null) 'displayName': displayName,
    if (phone != null) 'phone': phone,
  };
}

/// Lỗi đã chuẩn hoá từ ProblemDetails của backend.
class ApiException implements Exception {
  const ApiException({required this.title, this.detail, this.status = 0});

  final String title;
  final String? detail;
  final int status;

  /// Thông điệp hiển thị cho người dùng: ưu tiên `detail` như frontend.
  String get message {
    final value = detail;
    return value != null && value.isNotEmpty ? value : title;
  }

  @override
  String toString() => 'ApiException($status): $message';
}
