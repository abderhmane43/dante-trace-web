import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🔥 للإهتزازات (Haptic Feedback)
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد مهم جداً لفحص بيئة الويب
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

// 🔥 المسارات المطلقة
import 'package:dante_trace_mobile/services/api_service.dart';
import 'package:dante_trace_mobile/screens/admin/admin_dashboard_screen.dart'; 
import 'package:dante_trace_mobile/screens/admin/admin_web_dashboard.dart'; // 🔥 استيراد لوحة تحكم الويب الجديدة
import 'package:dante_trace_mobile/screens/customer/customer_dashboard_screen.dart'; 
import 'package:dante_trace_mobile/screens/driver/driver_dashboard_screen.dart';   
import 'package:dante_trace_mobile/screens/collector/collector_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // 🔥 Focus Nodes للتحكم الذكي بالكيبورد
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;

  // 🎨 ألوان الشركة
  final Color primaryColor = const Color(0xFFD32F2F); 
  final Color darkColor = const Color(0xFF1E293B);    
  final Color softBg = const Color(0xFFF8FAFC);

  // 🪄 الأنيميشن
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // 🔐 أدوات التشفير والبصمة
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // 🔥 حماية الويب: جعلنا البصمة Nullable لكي لا ينهار المتصفح
  final LocalAuthentication? _localAuth = kIsWeb ? null : LocalAuthentication();
  
  // قائمة الحسابات المحفوظة
  Map<String, dynamic> _savedAccounts = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));
    _animController.forward();
    
    _loadSavedAccounts();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. إدارة الحسابات في الذاكرة الآمنة
  // ==========================================
  Future<void> _loadSavedAccounts() async {
    try {
      String? accountsJson = await _secureStorage.read(key: 'saved_accounts');
      if (accountsJson != null) {
        setState(() => _savedAccounts = jsonDecode(accountsJson));
      }
    } catch (e) {
      debugPrint("Secure Storage not fully supported on this web browser, skipping.");
    }
  }

  Future<void> _saveAccountToSecureStorage(String username, String password) async {
    try {
      _savedAccounts[username] = password;
      await _secureStorage.write(key: 'saved_accounts', value: jsonEncode(_savedAccounts));
    } catch (e) {
      debugPrint("Skipping secure storage save on web");
    }
  }

  Future<void> _removeSavedAccount(String username) async {
    if (!kIsWeb) HapticFeedback.mediumImpact(); 
    setState(() => _savedAccounts.remove(username));
    
    try {
      await _secureStorage.write(key: 'saved_accounts', value: jsonEncode(_savedAccounts));
    } catch (e) {
      debugPrint("Skipping secure storage update on web");
    }
    
    if (_savedAccounts.isEmpty && Navigator.canPop(context)) {
      Navigator.pop(context); 
    }
  }

  // ==========================================
  // 2. التحقق بالبصمة (Pro Mode)
  // ==========================================
  Future<void> _authenticateAndFill(String username, String password) async {
    if (!kIsWeb) HapticFeedback.lightImpact();
    
    // 🔥 حماية قوية: تخطي البصمة فوراً إذا كنا على الويب
    if (kIsWeb || _localAuth == null) {
      _fillDataAndLogin(username, password);
      return;
    }

    try {
      bool canCheck = await _localAuth!.canCheckBiometrics || await _localAuth!.isDeviceSupported();

      if (!canCheck) {
        _fillDataAndLogin(username, password);
        return;
      }

      bool didAuthenticate = await _localAuth!.authenticate(
        localizedReason: 'تأكيد الهوية للدخول كـ $username',
      );

      if (didAuthenticate) {
        HapticFeedback.heavyImpact(); 
        _fillDataAndLogin(username, password);
      }
    } catch (e) {
      _fillDataAndLogin(username, password);
    }
  }

  void _fillDataAndLogin(String username, String password) {
    setState(() {
      _usernameController.text = username;
      _passwordController.text = password;
    });
    
    if (Navigator.canPop(context)) Navigator.pop(context);
    
    Future.delayed(const Duration(milliseconds: 300), () {
      _handleLogin();
    });
  }

  // ==========================================
  // 3. نافذة عرض الحسابات (Swipe to delete)
  // ==========================================
  void _showSavedAccountsSheet() {
    if (_savedAccounts.isEmpty) return;
    if (!kIsWeb) HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder( 
          builder: (context, setSheetState) {
            return Center( 
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 20),
                      Text("الحسابات المحفوظة", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkColor)),
                      Text("اسحب لليسار لحذف الحساب", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 15),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _savedAccounts.keys.length,
                          itemBuilder: (context, index) {
                            String user = _savedAccounts.keys.elementAt(index);
                            String pass = _savedAccounts[user];
                            return Dismissible( 
                              key: Key(user),
                              direction: DismissDirection.endToStart,
                              onDismissed: (direction) {
                                _removeSavedAccount(user);
                                setSheetState(() {}); 
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.delete_outline, color: Colors.red),
                              ),
                              child: Card(
                                elevation: 0,
                                color: softBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12), 
                                  side: BorderSide(color: Colors.grey.shade200)
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: primaryColor.withOpacity(0.1),
                                    child: Icon(Icons.person, color: primaryColor),
                                  ),
                                  title: Text(user, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                  trailing: Icon(kIsWeb ? Icons.login_rounded : Icons.fingerprint, color: primaryColor),
                                  onTap: () => _authenticateAndFill(user, pass),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  // ==========================================
  // 4. المحرك الرئيسي لتسجيل الدخول والتوجيه الذكي
  // ==========================================
  Future<void> _handleLogin() async {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text;

    FocusScope.of(context).unfocus();

    if (username.isEmpty || password.isEmpty) {
      if (!kIsWeb) HapticFeedback.vibrate();
      _showSnackBar('يرجى ملء جميع الحقول المطلوبة', Colors.orange.shade800, Icons.warning_rounded);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      bool success = await ApiService.login(username, password);
      
      if (!mounted) return;

      if (success) {
        await _saveAccountToSecureStorage(username, password);
        String? role = await ApiService.getUserRole(); 
        
        if (!mounted) return;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        if (role != null) await prefs.setString('role', role);

        if (!kIsWeb) HapticFeedback.heavyImpact();

        if (!mounted) return;
        setState(() => _isLoading = false);

        // 🔥 التوجيه الذكي بناءً على دور المستخدم ونوع الجهاز (موبايل أم ويب)
        if (username == "dante_customer" || role == 'customer') {
          _navigate(const CustomerDashboardScreen());
        } 
        else if (role == 'admin') {
          // التوجيه للويب أو الموبايل
          if (kIsWeb) {
            _navigate(const AdminWebDashboard());
          } else {
            _navigate(const AdminDashboardScreen());
          }
        } 
        else if (role == 'driver') {
          _navigate(const DriverDashboardScreen()); 
        } 
        else if (role == 'collector') {
          _navigate(const CollectorDashboardScreen());
        } 
        else {
          // الحالة الافتراضية
          _navigate(const AdminDashboardScreen());
        }

      } else {
        if (!kIsWeb) HapticFeedback.vibrate(); 
        setState(() => _isLoading = false);
        _showSnackBar('بيانات الدخول غير صحيحة', Colors.red.shade800, Icons.error_outline_rounded);
      }
    } catch (e) {
      if (!mounted) return;
      if (!kIsWeb) HapticFeedback.vibrate();
      setState(() => _isLoading = false);
      _showSnackBar('تعذر الاتصال بالخادم. تحقق من الإنترنت.', Colors.red.shade800, Icons.wifi_off_rounded);
    }
  }

  // 🔥 دالة التوجيه المحدثة (Direct Route Reset) لحل مشكلة الويب نهائياً
  void _navigate(Widget screen) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => screen),
      (route) => false, // 🔥 يمسح كل الشاشات السابقة لضمان عدم تعارض الـ History
    );
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(20),
      elevation: 10,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // 🖥️ تحسين مظهر شاشة الدخول للويب (تحديد أقصى عرض للنموذج)
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: softBg,
        resizeToAvoidBottomInset: true, 
        body: Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height, maxWidth: isDesktop ? 500 : double.infinity),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    _buildHeader(size, isDesktop),
                    FadeTransition(opacity: _fadeAnimation, child: _buildLoginForm()),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0, top: 20.0),
                      child: _buildFooter(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Size size, bool isDesktop) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: isDesktop ? 300 : size.height * 0.35, 
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primaryColor, const Color(0xFF991B1B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: isDesktop 
              ? BorderRadius.circular(30) 
              : const BorderRadius.only(bottomLeft: Radius.circular(50), bottomRight: Radius.circular(50)),
            boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
        ),
        SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 70, 
                    width: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.local_shipping, size: 50, color: primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text("DANTE TRACE", style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
              Text("Enterprise Logistics & ERP", style: GoogleFonts.cairo(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Transform.translate(
      offset: const Offset(0, -30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 15))],
            border: Border.all(color: Colors.grey.shade100)
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("مرحباً بك مجدداً 👋", style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: darkColor)),
              Text("قم بتسجيل الدخول للمتابعة", style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey.shade500)),
              const SizedBox(height: 30),
              
              _buildTextField(
                controller: _usernameController, 
                focusNode: _usernameFocus,
                nextFocus: _passwordFocus,
                hintText: "اسم المستخدم", 
                icon: Icons.person_outline_rounded,
                hasSavedAccounts: _savedAccounts.isNotEmpty,
                action: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              
              _buildTextField(
                controller: _passwordController, 
                focusNode: _passwordFocus,
                hintText: "كلمة المرور", 
                icon: Icons.lock_outline_rounded, 
                isPassword: true,
                action: TextInputAction.done,
                onSubmitted: (_) => _handleLogin(), 
              ),
              const SizedBox(height: 35),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    if (!kIsWeb) HapticFeedback.lightImpact();
                    _handleLogin();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: _isLoading ? 0 : 5,
                    shadowColor: primaryColor.withOpacity(0.5)
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : Text("تسجيل الدخول", style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String hintText, 
    required IconData icon, 
    bool isPassword = false, 
    bool hasSavedAccounts = false,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    TextInputAction? action,
    Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: isPassword ? _obscurePassword : false,
      textInputAction: action,
      onFieldSubmitted: onSubmitted ?? (_) {
        if (nextFocus != null) FocusScope.of(context).requestFocus(nextFocus);
      },
      style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: darkColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.cairo(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 22),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey.shade400, size: 20), 
              onPressed: () {
                if (!kIsWeb) HapticFeedback.selectionClick();
                setState(() => _obscurePassword = !_obscurePassword);
              }
            ) 
          : (hasSavedAccounts 
              ? IconButton(
                  icon: Icon(Icons.arrow_drop_down_circle_outlined, color: primaryColor),
                  onPressed: _showSavedAccountsSheet,
                ) 
              : null),
        filled: true,
        fillColor: softBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryColor.withOpacity(0.5), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text("© 2026 Dante Cloud - Algeria", style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 11)),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code_rounded, size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 5),
            Text("Engineered by ", style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 11)),
            Text("Abderrhmane Guettaf", style: GoogleFonts.poppins(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}