import 'dart:async';

import 'package:flutter/material.dart';

import 'pages/auth_gate.dart';
import 'pages/register_page.dart';
import 'services/auth_api.dart';
import 'services/token_store.dart';
import 'state/auth_controller.dart';
import 'state/auth_scope.dart';
import 'theme/app_theme.dart';

/// Tương đương `src/App.tsx`: bọc AuthProvider + router.
class BonBonApp extends StatefulWidget {
  const BonBonApp({super.key, this.controller});

  /// Cho phép truyền controller giả trong test.
  final AuthController? controller;

  @override
  State<BonBonApp> createState() => _BonBonAppState();
}

class _BonBonAppState extends State<BonBonApp> {
  late final bool _ownsController;
  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    if (widget.controller != null) {
      _auth = widget.controller!;
    } else {
      final tokenStore = SharedPrefsTokenStore();
      _auth = AuthController(
        api: AuthService(tokenStore: tokenStore),
        tokenStore: tokenStore,
      );
    }
    unawaited(_auth.hydrate());
  }

  @override
  void dispose() {
    if (_ownsController) _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _auth,
      child: MaterialApp(
        title: 'BonBon',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const AuthGate(),
        routes: {
          '/register': (_) => const RegisterPage(),
        },
      ),
    );
  }
}
