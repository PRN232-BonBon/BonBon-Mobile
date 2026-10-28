import 'package:flutter/widgets.dart';

import 'auth_controller.dart';

/// Chia sẻ [AuthController] xuống cây widget, tương đương `useAuth()`.
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Lấy controller và rebuild widget khi trạng thái auth thay đổi.
  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'Không tìm thấy AuthScope trong cây widget.');
    return scope!.notifier!;
  }

  /// Lấy controller để gọi hành động, không đăng ký rebuild.
  static AuthController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'Không tìm thấy AuthScope trong cây widget.');
    return scope!.notifier!;
  }
}
