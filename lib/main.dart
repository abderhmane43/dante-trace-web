import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 🔥 تم فك التعليق: الآن التطبيق يستدعي شاشاتك الحقيقية التي برمجناها
import 'screens/shared/login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/driver/driver_dashboard_screen.dart';
import 'screens/customer/customer_dashboard_screen.dart';

void main() async {
  // التأكد من تهيئة الـ Widgets قبل تشغيل أي كود غير متزامن (Async)
  WidgetsFlutterBinding.ensureInitialized();
  
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

      // توجيه المستخدم حسب دوره في النظام للشاشات الحقيقية المليئة بالميزات
      if (role == 'admin') {
        defaultHome = const AdminDashboardScreen();
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

  const DanteTraceApp({Key? key, required this.homeScreen}) : super(key: key);

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

// 💥 ملاحظة: لقد قمت بحذف الشاشات الوهمية من هنا نهائياً!