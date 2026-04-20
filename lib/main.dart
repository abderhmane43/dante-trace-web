import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/shared/login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_web_dashboard.dart'; 
import 'screens/driver/driver_dashboard_screen.dart';
import 'screens/customer/customer_dashboard_screen.dart';

// 🔥 الإضافة 1: استيراد شاشة الحارس
import 'screens/shared/splash_screen.dart'; 

void main() async {
  // التأكد من تهيئة الـ Widgets قبل تشغيل أي كود غير متزامن (Async)
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔥 الإضافة 2: إذا كان الجهاز هاتفاً (Android/iOS)، يجب أن يمر على الحارس أولاً دائماً لفحص التحديث
  if (!kIsWeb) {
    runApp(const DanteTraceApp(homeScreen: SplashScreen()));
    return; // نوقف التنفيذ هنا للهاتف لكي تتكفل شاشة الحارس بالباقي
  }

  // ==========================================================
  // 👇 كل ما بالأسفل هو كودك الأصلي، وسيعمل للويب بشكل مثالي 👇
  // ==========================================================
  
  // تحديد الشاشة الافتراضية مبدئياً لتكون شاشة تسجيل الدخول
  Widget defaultHome = const LoginScreen(); 
  
  try {
    // جلب التوكن من التخزين المحلي
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // المفتاح يطابق api_service.dart
    String? token = prefs.getString('auth_token');

    // التحقق من صلاحية التوكن (موجود وغير منتهي الصلاحية)
    if (token != null && !JwtDecoder.isExpired(token)) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      String role = decodedToken['role'] ?? '';

      // التوجيه الذكي عند فتح التطبيق (أو عمل Refresh) والمستخدم مسجل دخوله بالفعل
      if (role == 'admin') {
        if (kIsWeb) {
          defaultHome = const AdminWebDashboard(); // 💻 توجيه للوحة الويب الكاملة
        } else {
          defaultHome = const AdminDashboardScreen(); // 📱 توجيه لشاشة الهاتف
        }
      } else if (role == 'driver' || role == 'collector') {
        defaultHome = const DriverDashboardScreen();
      } else if (role == 'customer') {
        defaultHome = const CustomerDashboardScreen();
      }
    } else if (token != null) {
      // إذا كان التوكن منتهي الصلاحية، نمسح البيانات القديمة
      await prefs.clear();
    }
  } catch (e) {
    debugPrint("🚨 خطأ في قراءة جلسة الدخول: $e");
  }

  // تشغيل التطبيق مع تمرير الشاشة المناسبة
  runApp(DanteTraceApp(homeScreen: defaultHome));
}

class DanteTraceApp extends StatelessWidget {
  final Widget homeScreen;

  const DanteTraceApp({super.key, required this.homeScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dante Trace ERP',
      debugShowCheckedModeBanner: false,
      
      // 🌍 إعدادات اللغة العربية (الجزائر)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'DZ'), 
      ],
      locale: const Locale('ar', 'DZ'),

      // 🎨 تصميم التطبيق (Material 3 + خط Cairo + اللون الأساسي)
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD32F2F), // الأحمر المعتمد للمشروع
          primary: const Color(0xFFD32F2F),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      
      home: homeScreen,
    );
  }
}