import 'package:flutter/material.dart';

import '../pages/login_page.dart';
import '../state/auth_controller.dart';
import '../state/auth_scope.dart';
import '../theme/app_theme.dart';

typedef TrackingAuthBuilder = Widget Function(
  BuildContext context,
  AuthController auth,
);

/// Bắt buộc đăng nhập trước khi mở danh sách chuyến hoặc bản đồ tracking.
///
/// Backend dùng JWT để biết ai đang xem và chỉ cho người thuộc booking
/// (người thuê/chủ xe) vào group SignalR.
class TrackingAuthGate extends StatelessWidget {
  const TrackingAuthGate({
    super.key,
    required this.builder,
    this.title = 'Theo dõi chuyến đi',
  });

  final TrackingAuthBuilder builder;
  final String title;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    if (!auth.isAuthenticated) {
      return _LoginRequired(title: title);
    }
    return builder(context, auth);
  }
}

class _LoginRequired extends StatelessWidget {
  const _LoginRequired({required this.title});

  final String title;

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LoginPage(popOnSuccess: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: AppColors.primarySoft,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bạn cần đăng nhập',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'BonBon dùng tài khoản đang đăng nhập để xác định bạn là '
                    'người thuê hay chủ xe của chuyến. Chỉ người thuộc chuyến '
                    'mới xem được vị trí xe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openLogin(context),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Đăng nhập để xem bản đồ'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Chưa có tài khoản? Chọn "Đăng ký ngay" trong màn hình '
                    'đăng nhập.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
