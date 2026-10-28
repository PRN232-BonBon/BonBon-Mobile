import 'package:flutter/material.dart';

import '../state/auth_controller.dart';
import '../state/auth_scope.dart';
import '../theme/app_theme.dart';
import 'dashboard_page.dart';
import 'login_page.dart';

/// Tương đương `ProtectedRoute` + routes trong `App.tsx`.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);

    return switch (auth.status) {
      AuthStatus.loading => const _LoadingScreen(),
      AuthStatus.authenticated => const DashboardPage(),
      AuthStatus.unauthenticated => const LoginPage(),
    };
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'Đang tải…',
          style: TextStyle(fontSize: 14, color: AppColors.textDim),
        ),
      ),
    );
  }
}
