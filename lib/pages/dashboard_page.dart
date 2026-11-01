import 'package:flutter/material.dart';

import '../models/auth.dart';
import '../state/auth_scope.dart';
import '../theme/app_theme.dart';
import '../tracking/tracking_trips_page.dart';
import '../widgets/common.dart';
import 'my_vehicles_page.dart';
import 'rent_vehicles_page.dart';

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

  Future<void> _openChangePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (!mounted || changed != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu.')));
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
                      onPressed: busy ? null : _openChangePassword,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Đổi mật khẩu'),
                    ),
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
          const _TrackingCard(),
          const SizedBox(height: 16),
          const _VehiclesCard(),
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

class _TrackingCard extends StatelessWidget {
  const _TrackingCard();

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.near_me_rounded,
                  size: 19,
                  color: AppColors.primarySoft,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Theo dõi chuyến đi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Xem vị trí xe do thiết bị GPS Traccar gửi về backend. Người thuê '
            'theo dõi xe tới điểm lấy, chủ xe theo dõi chiều trả xe — chỉ mở '
            'được khi tài khoản đang đăng nhập thuộc chuyến.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TrackingTripsPage(),
                ),
              ),
              icon: const Icon(Icons.map_rounded, size: 16),
              label: const Text('Mở theo dõi chuyến'),
            ),
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
    final initial = fullName.isEmpty
        ? '?'
        : fullName.characters.first.toUpperCase();

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

class _VehiclesCard extends StatelessWidget {
  const _VehiclesCard();

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final account = AuthScope.of(context).account;
    final isOwner = account?.roles.contains('VehicleOwner') == true;

    return CardSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.car_rental_rounded,
                  size: 19,
                  color: AppColors.primarySoft,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Thuê xe',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Xem danh sách xe đang cho thuê, tính giá theo ngày hoặc theo giờ '
            'rồi tạo chuyến thuê ngay trên app.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _open(context, const RentVehiclesPage()),
              icon: const Icon(Icons.search_rounded, size: 16),
              label: const Text('Xem danh sách xe'),
            ),
          ),
          if (isOwner) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _open(context, const MyVehiclesPage()),
                icon: const Icon(Icons.garage_rounded, size: 16),
                label: const Text('Xe của tôi'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = AuthScope.read(context);
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await auth.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'Đổi mật khẩu thất bại.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Đổi mật khẩu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              if (_error != null) ErrorBanner(message: _error!),
              AppTextField(
                label: 'Mật khẩu hiện tại',
                controller: _currentController,
                obscureText: true,
                validator: (value) => (value ?? '').isEmpty
                    ? 'Vui lòng nhập mật khẩu hiện tại.'
                    : null,
              ),
              AppTextField(
                label: 'Mật khẩu mới',
                controller: _newController,
                hint: 'Tối thiểu 8 ký tự',
                obscureText: true,
                validator: (value) => (value ?? '').length < 8
                    ? 'Mật khẩu mới phải có ít nhất 8 ký tự.'
                    : null,
              ),
              AppTextField(
                label: 'Nhập lại mật khẩu mới',
                controller: _confirmController,
                obscureText: true,
                validator: (value) => value != _newController.text
                    ? 'Mật khẩu xác nhận không khớp.'
                    : null,
              ),
              PrimaryButton(
                label: 'Lưu',
                loadingLabel: 'Đang lưu…',
                loading: _loading,
                onPressed: _submit,
              ),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Huỷ'),
              ),
            ],
          ),
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
          _TokenRow(
            label: 'Refresh Token',
            value: refreshToken,
            truncate: true,
          ),
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
