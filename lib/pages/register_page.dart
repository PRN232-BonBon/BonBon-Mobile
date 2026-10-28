import 'package:flutter/material.dart';

import '../models/auth.dart';
import '../state/auth_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Tương đương `src/pages/RegisterPage.tsx`.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _messageFor(Object error) =>
      error is ApiException ? error.message : 'Đăng ký thất bại.';

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Vui lòng nhập email.';
    if (!_emailPattern.hasMatch(email)) return 'Email không hợp lệ.';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp.');
      return;
    }

    FocusScope.of(context).unfocus();
    final auth = AuthScope.read(context);
    final navigator = Navigator.of(context);

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await auth.register(
        RegisterRequest(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          displayName: _emptyToNull(_displayNameController.text),
          phone: _emptyToNull(_phoneController.text),
        ),
      );
      // Đăng ký xong tự đăng nhập: AuthGate đã chuyển sang Dashboard,
      // chỉ cần đóng trang đăng ký khỏi stack.
      if (mounted) navigator.pop();
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      maxWidth: 420,
      child: CardSurface(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BonBonLogo(),
              const SizedBox(height: 8),
              const Text(
                'Tạo tài khoản',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null) ErrorBanner(message: _error!),
              AppTextField(
                label: 'Họ và tên *',
                controller: _fullNameController,
                hint: 'Nguyễn Văn A',
                autofocus: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Vui lòng nhập họ và tên.'
                    : null,
              ),
              AppTextField(
                label: 'Email *',
                controller: _emailController,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: _validateEmail,
              ),
              AppTextField(
                label: 'Mật khẩu *',
                controller: _passwordController,
                hint: 'Tối thiểu 6 ký tự',
                obscureText: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => (value ?? '').length < 6
                    ? 'Mật khẩu tối thiểu 6 ký tự.'
                    : null,
              ),
              AppTextField(
                label: 'Xác nhận mật khẩu *',
                controller: _confirmPasswordController,
                hint: 'Nhập lại mật khẩu',
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: (value) => (value ?? '').isEmpty
                    ? 'Vui lòng nhập lại mật khẩu.'
                    : null,
              ),
              AppTextField(
                label: 'Tên hiển thị',
                controller: _displayNameController,
                hint: 'Tuỳ chọn',
                textInputAction: TextInputAction.next,
              ),
              AppTextField(
                label: 'Số điện thoại',
                controller: _phoneController,
                hint: 'Tuỳ chọn',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                onFieldSubmitted: (_) => _submit(),
              ),
              PrimaryButton(
                label: 'Đăng ký',
                loadingLabel: 'Đang tạo tài khoản…',
                loading: _loading,
                onPressed: _submit,
              ),
              AuthSwitch(
                leading: 'Đã có tài khoản?',
                action: 'Đăng nhập',
                onPressed: _loading ? () {} : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
