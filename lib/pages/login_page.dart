import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/auth.dart';
import '../services/google_auth.dart';
import '../state/auth_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Tương đương `src/pages/LoginPage.tsx`.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _messageFor(Object error) =>
      error is ApiException ? error.message : 'Đăng nhập thất bại.';

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    final auth = AuthScope.read(context);

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await auth.login(
        LoginRequest(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          deviceInfo: 'BonBon Mobile (${defaultTargetPlatform.name})',
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    FocusScope.of(context).unfocus();
    final auth = AuthScope.read(context);

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final idToken = await GoogleAuth.signIn();
      await auth.googleLogin(idToken);
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
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
                'Đăng nhập',
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
                label: 'Email',
                controller: _emailController,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofocus: true,
                autofillHints: const [AutofillHints.email],
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Vui lòng nhập email.'
                    : null,
              ),
              AppTextField(
                label: 'Mật khẩu',
                controller: _passwordController,
                hint: '••••••••',
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Vui lòng nhập mật khẩu.' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              PrimaryButton(
                label: 'Đăng nhập',
                loadingLabel: 'Đang đăng nhập…',
                loading: _loading,
                onPressed: _submit,
              ),
              if (GoogleAuth.isConfigured) ...[
                const DividerLabel(label: 'hoặc'),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _googleSignIn,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'G',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4285F4),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Đăng nhập với Google'),
                      ],
                    ),
                  ),
                ),
              ],
              AuthSwitch(
                leading: 'Chưa có tài khoản?',
                action: 'Đăng ký ngay',
                onPressed: _loading
                    ? () {}
                    : () => Navigator.of(context).pushNamed('/register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
