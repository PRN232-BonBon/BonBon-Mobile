import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';
import '../models/auth.dart';

/// Bọc `google_sign_in` 7.x, chỉ trả về `idToken` để gửi lên
/// `/api/auth/google-login` (giống `GoogleLogin` của bản web).
class GoogleAuth {
  const GoogleAuth._();

  static Future<void>? _initialization;

  static bool get isConfigured => AppConfig.isGoogleConfigured;

  static Future<String> signIn() async {
    final instance = GoogleSignIn.instance;

    try {
      await (_initialization ??= instance.initialize(
        clientId:
            AppConfig.googleClientId.isEmpty ? null : AppConfig.googleClientId,
        serverClientId: AppConfig.googleServerClientId.isEmpty
            ? null
            : AppConfig.googleServerClientId,
      ));

      if (!instance.supportsAuthenticate()) {
        throw const ApiException(
          title: 'Google login thất bại',
          detail: 'Nền tảng này không hỗ trợ đăng nhập Google trực tiếp.',
        );
      }

      final account = await instance.authenticate();
      final idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(
          title: 'Google login thất bại',
          detail: 'Không lấy được idToken. Kiểm tra GOOGLE_SERVER_CLIENT_ID '
              '(Web client ID) và SHA-1 của app trên Google Cloud Console.',
        );
      }

      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const ApiException(
          title: 'Google login thất bại',
          detail: 'Bạn đã huỷ đăng nhập Google.',
        );
      }
      throw ApiException(
        title: 'Google login thất bại',
        detail: error.description ?? 'Không thể đăng nhập bằng Google.',
      );
    }
  }
}
