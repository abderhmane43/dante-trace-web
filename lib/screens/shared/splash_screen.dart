import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart'; // 🔥 مكتبة فتح الروابط للتحميل المباشر

// 🔥 المسارات المطلقة لتجنب أي تعارض
import 'package:dante_trace_mobile/services/api_service.dart';
import 'package:dante_trace_mobile/screens/shared/login_screen.dart';
import 'package:dante_trace_mobile/screens/admin/admin_dashboard_screen.dart';
import 'package:dante_trace_mobile/screens/admin/admin_web_dashboard.dart';
import 'package:dante_trace_mobile/screens/driver/driver_dashboard_screen.dart';
import 'package:dante_trace_mobile/screens/customer/customer_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  bool _needsUpdate = false;
  String _currentVersion = "";
  String _requiredVersion = "";
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animController);
    _animController.forward();

    _runGuardChecks();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // 🛡️ المحرك الأساسي للحارس (Guard Engine)
  Future<void> _runGuardChecks() async {
    // 1. إعطاء وقت قصير للأنيميشن واللوجو
    await Future.delayed(const Duration(seconds: 2));

    // 2. التحقق من الإصدار (لا يتم على الويب لأن الويب يتحدث تلقائياً)
    if (!kIsWeb) {
      try {
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        _currentVersion = packageInfo.version;
        _requiredVersion = await ApiService.getRequiredAppVersion();

        if (_isUpdateRequired(_currentVersion, _requiredVersion)) {
          if (mounted) {
            setState(() {
              _needsUpdate = true;
            });
          }
          return; // 🛑 إيقاف الدخول وإظهار شاشة التحديث الإجبارية
        }
      } catch (e) {
        debugPrint("فشل فحص الإصدار: $e");
      }
    }

    // 3. إذا كان الإصدار سليماً، ننتقل للفحص الأمني للتوكن
    _checkTokenAndNavigate();
  }

  // 🧠 خوارزمية مقارنة الإصدارات
  bool _isUpdateRequired(String current, String required) {
    try {
      List<int> currentParts = current.split('.').map(int.parse).toList();
      List<int> requiredParts = required.split('.').map(int.parse).toList();

      for (int i = 0; i < requiredParts.length; i++) {
        int c = i < currentParts.length ? currentParts[i] : 0;
        int r = requiredParts[i];
        if (c < r) return true;  // النسخة الحالية أقدم
        if (c > r) return false; // النسخة الحالية أحدث
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  Future<void> _checkTokenAndNavigate() async {
    Widget nextScreen = const LoginScreen();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      if (token != null && !JwtDecoder.isExpired(token)) {
        Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
        String role = decodedToken['role'] ?? '';

        if (role == 'admin') {
          nextScreen = kIsWeb ? const AdminWebDashboard() : const AdminDashboardScreen();
        } else if (role == 'driver' || role == 'collector') {
          nextScreen = const DriverDashboardScreen();
        } else if (role == 'customer') {
          nextScreen = const CustomerDashboardScreen();
        }
      } else if (token != null) {
        await prefs.clear();
      }
    } catch (e) {
      debugPrint("Auth Error: $e");
    }

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => nextScreen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFFD32F2F);
    final Color darkBlue = const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: _needsUpdate ? primaryColor : darkBlue,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _needsUpdate 
            ? _buildUpdateUI() // 🛑 تفعيل الشاشة الحمراء للتحديث
            : _buildLoadingUI(), // ⏳ شاشة التحميل العادية
        ),
      ),
    );
  }

  // ⏳ واجهة التحميل الطبيعية
  Widget _buildLoadingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/images/logo.png', height: 120, errorBuilder: (c, e, s) => const Icon(Icons.local_shipping, size: 80, color: Colors.white)),
        const SizedBox(height: 20),
        Text("DANTE TRACE", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)),
        const SizedBox(height: 30),
        const CircularProgressIndicator(color: Colors.white),
      ],
    );
  }

  // 🛑 واجهة التحديث الإجباري (مع زر التحميل المباشر من GitHub)
  Widget _buildUpdateUI() {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.system_update_rounded, size: 100, color: Colors.white),
          const SizedBox(height: 30),
          Text("تحديث إجباري متاح", style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 15),
          Text(
            "نسختك الحالية ($_currentVersion) قديمة جداً.\nيرجى الضغط على الزر أدناه لتحميل وتثبيت أحدث نسخة لضمان استمرار عمل النظام بكفاءة.",
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 16, color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 40),
          
          // 🔥 زر التحديث التلقائي بالرابط المباشر
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFD32F2F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 8,
              ),
              icon: const Icon(Icons.download_rounded, size: 24),
              label: Text("تحديث التطبيق الآن", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
              onPressed: () async {
                // 🔗 الرابط المباشر للملف على GitHub
                final Uri apkUrl = Uri.parse("https://github.com/abderhmane43/dante-app-releases/releases/download/v1.0.0/app-release.apk"); 
                
                try {
                  if (await canLaunchUrl(apkUrl)) {
                    // فتح الرابط في المتصفح الخارجي ليبدأ التحميل فوراً
                    await launchUrl(apkUrl, mode: LaunchMode.externalApplication);
                  } else {
                    debugPrint("لا يمكن فتح الرابط المباشر");
                  }
                } catch (e) {
                  debugPrint("تعذر فتح رابط التحديث: $e");
                }
              },
            ),
          ),
          
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
            child: Text("النسخة المطلوبة: $_requiredVersion", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          )
        ],
      ),
    );
  }
}