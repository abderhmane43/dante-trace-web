import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔥 الاستيرادات المطلقة (Absolute Imports) مطابقة تماماً لشاشات التطبيق
import 'package:dante_trace_mobile/screens/admin/admin_dashboard_screen.dart';
import 'package:dante_trace_mobile/screens/admin/master_tracking_screen.dart';
import 'package:dante_trace_mobile/screens/admin/logistics_management_screen.dart';
import 'package:dante_trace_mobile/screens/admin/agenda_screen.dart';
import 'package:dante_trace_mobile/screens/admin/daily_manifest_screen.dart';
import 'package:dante_trace_mobile/screens/admin/customer_orders_review_screen.dart';
import 'package:dante_trace_mobile/screens/admin/admin_fleet_screen.dart';
import 'package:dante_trace_mobile/screens/finance/financial_settlement_screen.dart'; 
import 'package:dante_trace_mobile/screens/admin/admin_expense_review_screen.dart';
import 'package:dante_trace_mobile/screens/finance/invoices_screen.dart'; 
import 'package:dante_trace_mobile/screens/admin/sales_management_screen.dart';
import 'package:dante_trace_mobile/screens/admin/admin_b2b_pricing_screen.dart';
import 'package:dante_trace_mobile/screens/admin/customer_prices_screen.dart';
import 'package:dante_trace_mobile/screens/admin/user_management_screen.dart';
import 'package:dante_trace_mobile/screens/admin/add_user_screen.dart';

import 'package:dante_trace_mobile/screens/shared/login_screen.dart';

class AdminWebDashboard extends StatefulWidget {
  const AdminWebDashboard({super.key});

  @override
  State<AdminWebDashboard> createState() => _AdminWebDashboardState();
}

class _AdminWebDashboardState extends State<AdminWebDashboard> {
  final Color darkBlue = const Color(0xFF1E293B);
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color softBg = const Color(0xFFF8FAFC);

  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // 🔥 ترتيب الشاشات هنا مطابق 100% لقائمة التطبيق الجانبية (Drawer)
    // لاحظ أن AdminDashboardScreen في الفهرس 0 تتضمن الزر الجديد للمصروفات!
    _screens = [
      const AdminDashboardScreen(),         // 0: اللوحة الرئيسية
      const MasterTrackingScreen(),         // 1: المراقبة الشاملة للتوجيه
      const LogisticsManagementScreen(),    // 2: غرفة اللوجستيات
      const AgendaScreen(),                 // 3: المفكرة اللوجستية
      const DailyManifestScreen(),          // 4: تجهيز الشحنات
      const CustomerOrdersReviewScreen(),   // 5: مراجعة طلبات الزبائن
      const AdminFleetScreen(),             // 6: مراقبة الأسطول
      const FinancialSettlementScreen(),    // 7: تصفية الخزينة (NFC)
      const AdminExpenseReviewScreen(),     // 8: مراجعة مصاريف السائقين
      const InvoicesScreen(),               // 9: سجل الفواتير والمبيعات
      const SalesManagementScreen(),        // 10: إدارة المنتجات (المخزن)
      const AdminB2BPricingScreen(),        // 11: تسعير الشركات
      const CustomerPricesScreen(),         // 12: عروض الأسعار
      const UserManagementScreen(),         // 13: قائمة المستخدمين
      const AddUserScreen(),                // 14: إضافة مستخدم جديد
    ];
  }

  Future<void> _handleLogout() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text("تسجيل الخروج", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue)),
          ],
        ),
        content: Text("هل أنت متأكد أنك تريد تسجيل الخروج؟", style: GoogleFonts.cairo(fontSize: 15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey.shade600, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("نعم، خروج", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
          )
        ],
      )
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); 
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (context) => const LoginScreen()), 
          (route) => false
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;

    Widget sidebarContent = Container(
      width: 280,
      color: darkBlue,
      child: Column(
        children: [
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: primaryRed, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("DANTE CLOUD", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text("Enterprise ERP Portal", style: GoogleFonts.cairo(fontSize: 10, color: Colors.white54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12, thickness: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 5),
              physics: const BouncingScrollPhysics(),
              children: [
                // زر رئيسي للعودة للإحصائيات
                _buildNavItem(Icons.home_rounded, "اللوحة الرئيسية (الإحصائيات)", 0),
                
                // ================== الفرع الأول ==================
                _buildSectionTitle("العمليات واللوجستيات الميدانية"),
                _buildNavItem(Icons.history_edu_rounded, "المراقبة الشاملة للتوجيه 📜", 1),
                _buildNavItem(Icons.dashboard_customize_rounded, "غرفة اللوجستيات والتجهيز", 2),
                _buildNavItem(Icons.edit_calendar_rounded, "المفكرة اللوجستية (Agenda) 📅", 3),
                _buildNavItem(Icons.assignment_turned_in_rounded, "تجهيز شحنات اليوم (PDF) 🚛", 4),
                _buildNavItem(Icons.fact_check_rounded, "مراجعة طلبات الزبائن", 5),

                // ================== الفرع الثاني ==================
                _buildSectionTitle("الأسطول والمحاسبة المالية"),
                _buildNavItem(Icons.airport_shuttle_rounded, "مراقبة الأسطول (الرادار)", 6),
                _buildNavItem(Icons.attach_money_rounded, "تصفية الخزينة (NFC)", 7),
                _buildNavItem(Icons.price_check_rounded, "مراجعة مصاريف السائقين 💸", 8),
                _buildNavItem(Icons.receipt_long_rounded, "سجل الفواتير والمبيعات", 9),

                // ================== الفرع الثالث ==================
                _buildSectionTitle("عملاء B2B والتسعير"),
                _buildNavItem(Icons.inventory_2_rounded, "إدارة المنتجات (المخزن)", 10),
                _buildNavItem(Icons.handshake_rounded, "تسعير الشركات (B2B) 🏢", 11),
                _buildNavItem(Icons.local_offer_rounded, "عروض الأسعار الخاصة", 12),

                // ================== الفرع الرابع ==================
                _buildSectionTitle("إدارة النظام والمستخدمين"),
                _buildNavItem(Icons.group_rounded, "قائمة المستخدمين", 13),
                _buildNavItem(Icons.person_add_alt_1_rounded, "إضافة مستخدم جديد 👤", 14),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            title: Text("تسجيل الخروج", style: GoogleFonts.cairo(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
            onTap: _handleLogout,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: darkBlue,
      appBar: isDesktop ? null : AppBar(
        backgroundColor: darkBlue,
        foregroundColor: Colors.white,
        title: Text("DANTE CLOUD", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      drawer: isDesktop ? null : Drawer(child: sidebarContent),
      body: Row(
        children: [
          if (isDesktop) sidebarContent,
          
          Expanded(
            child: Container(
              margin: EdgeInsets.only(top: isDesktop ? 10 : 0, bottom: isDesktop ? 10 : 0, left: isDesktop ? 10 : 0, right: isDesktop ? 0 : 0),
              decoration: BoxDecoration(
                color: softBg,
                borderRadius: isDesktop ? const BorderRadius.only(topLeft: Radius.circular(30), bottomLeft: Radius.circular(30)) : BorderRadius.zero,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(-5, 0))]
              ),
              child: ClipRRect(
                borderRadius: isDesktop ? const BorderRadius.only(topLeft: Radius.circular(30), bottomLeft: Radius.circular(30)) : BorderRadius.zero,
                child: _screens[_selectedIndex],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 20, left: 20, top: 15, bottom: 5),
      child: Text(title, style: GoogleFonts.cairo(color: primaryRed, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index) {
    bool isSelected = _selectedIndex == index;
    return ListTile(
      selected: isSelected,
      selectedTileColor: primaryRed.withValues(alpha: 0.9), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.white60, size: 18),
      title: Text(title, style: GoogleFonts.cairo(color: isSelected ? Colors.white : Colors.white70, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600)),
      onTap: () {
        setState(() => _selectedIndex = index);
        if (MediaQuery.of(context).size.width < 900 && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    );
  }
}