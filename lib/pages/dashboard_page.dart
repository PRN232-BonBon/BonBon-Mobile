import 'package:flutter/material.dart';

import '../models/auth.dart';
import '../state/auth_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Tương đương `src/pages/DashboardPage.tsx`.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? _loadingAction;
  String? _error;

  Future<void> _run(String action, Future<void> Function() task) async {
    setState(() {
      _error = null;
      _loadingAction = action;
    });

    try {
      await task();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ApiException
              ? error.message
              : 'Đăng xuất thất bại.';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final account = auth.account;
    final busy = _loadingAction != null;

    return PageScaffold(
      maxWidth: 680,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const BonBonLogo(fontSize: 22),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => _run('logout', auth.logout),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        _loadingAction == 'logout'
                            ? 'Đang đăng xuất…'
                            : 'Đăng xuất',
                      ),
                    ),
                    ElevatedButton(
                      onPressed: busy
                          ? null
                          : () => _run('logoutAll', auth.logoutAll),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        disabledBackgroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(
                        _loadingAction == 'logoutAll'
                            ? '…'
                            : 'Đăng xuất tất cả',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_error != null) ErrorBanner(message: _error!),
          _ProfileCard(account: account),
          const SizedBox(height: 16),
          _TokenCard(
            accountId: account?.accountId ?? '',
            accessToken: auth.accessToken ?? '',
            refreshToken: auth.refreshToken ?? '',
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.account});

  static const _roleColors = <String, Color>{
    'Admin': Color(0xFFF59E0B),
    'Customer': Color(0xFF22C55E),
    'VehicleOwner': Color(0xFF6366F1),
  };

  final AccountInfo? account;

  @override
  Widget build(BuildContext context) {
    final fullName = account?.fullName ?? '';
    final initial =
        fullName.isEmpty ? '?' : fullName.characters.first.toUpperCase();

    return CardSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                if (account?.displayName != null &&
                    account!.displayName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '@${account!.displayName}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  account?.email ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textDim,
                  ),
                ),
                if (account != null && account!.roles.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final role in account!.roles)
                        _RoleBadge(
                          role: role,
                          color: _roleColors[role] ?? AppColors.primary,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.color});

  final String role;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        border: Border.all(color: color.withValues(alpha: 0.33)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}

class _TokenCard extends StatelessWidget {
  const _TokenCard({
    required this.accountId,
    required this.accessToken,
    required this.refreshToken,
  });

  final String accountId;
  final String accessToken;
  final String refreshToken;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔑 TOKEN INFO',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 14),
          _TokenRow(label: 'Account ID', value: accountId),
          _TokenRow(label: 'Access Token', value: accessToken, truncate: true),
          _TokenRow(label: 'Refresh Token', value: refreshToken, truncate: true),
        ],
      ),
    );
  }
}

class _TokenRow extends StatefulWidget {
  const _TokenRow({
    required this.label,
    required this.value,
    this.truncate = false,
  });

  final String label;
  final String value;
  final bool truncate;

  @override
  State<_TokenRow> createState() => _TokenRowState();
}

class _TokenRowState extends State<_TokenRow> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    final display = widget.truncate && !_show && widget.value.length > 48
        ? '${widget.value.substring(0, 48)}…'
        : widget.value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textDim,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    display.isEmpty ? '—' : display,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.token,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              if (widget.truncate) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _show = !_show),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.border,
                    foregroundColor: AppColors.textMuted,
                    minimumSize: const Size(0, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: Text(_show ? 'Ẩn' : 'Xem'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
