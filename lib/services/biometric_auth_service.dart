import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // مفاتيح التخزين السري
  static const String _keyUsername = 'secure_username';
  static const String _keyPassword = 'secure_password';

  /// 1. فحص هل الجهاز يدعم البصمة أو التعرف على الوجه؟
  Future<bool> checkBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      return canAuthenticateWithBiometrics || isSupported;
    } catch (e) {
      return false;
    }
  }

  /// 2. إظهار نافذة البصمة للمستخدم
  Future<bool> authenticateWithBiometrics() async {
    bool isAvailable = await checkBiometrics();
    if (!isAvailable) return false;

    try {
      // 🔥 تم التعديل هنا: تمرير الخاصية الأساسية فقط لتجنب أي تعارض في المكتبات
      return await _auth.authenticate(
        localizedReason: 'الرجاء استخدام البصمة لتسجيل الدخول السريع إلى Dante Trace',
      );
    } catch (e) {
      return false;
    }
  }

  /// 3. حفظ بيانات الدخول (تُستدعى عندما يسجل المستخدم دخوله يدوياً بنجاح أول مرة)
  Future<void> saveCredentials(String username, String password) async {
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyPassword, value: password);
  }

  /// 4. جلب بيانات الدخول (تُستدعى بعد أن يضع المستخدم بصمته بنجاح)
  Future<Map<String, String>?> getCredentials() async {
    String? username = await _storage.read(key: _keyUsername);
    String? password = await _storage.read(key: _keyPassword);

    if (username != null && password != null) {
      return {'username': username, 'password': password};
    }
    return null; // لا توجد بيانات محفوظة
  }

  /// 5. مسح بيانات الدخول (تُستدعى عند تسجيل الخروج)
  Future<void> clearCredentials() async {
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyPassword);
  }
}