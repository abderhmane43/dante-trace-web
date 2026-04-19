import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 🔥 استخدام المسارات النسبية (Relative Paths) بالكامل لمنع تعارض الاستيراد
import '../../services/api_service.dart';
import '../../screens/shared/login_screen.dart';

import '../../screens/admin/user_management_screen.dart';
import '../../screens/admin/sales_management_screen.dart';
import '../../screens/admin/logistics_management_screen.dart';
import '../../screens/admin/customer_orders_review_screen.dart';
import '../../screens/finance/invoices_screen.dart'; 
import '../../screens/admin/customer_prices_screen.dart';
import '../../screens/admin/admin_fleet_screen.dart';
import '../../screens/admin/admin_b2b_pricing_screen.dart'; 
import '../../screens/finance/financial_settlement_screen.dart'; 
import '../../screens/admin/admin_expense_review_screen.dart';
import '../../screens/admin/add_user_screen.dart';
import '../../screens/admin/master_tracking_screen.dart';
import '../../screens/admin/agenda_screen.dart';
import '../../screens/admin/daily_manifest_screen.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkRed = const Color(0xFFB71C1C);

  void _nav(BuildContext context, Widget screen) {
    Navigator.pop(context); // إغلاق القائمة الجانبية أولاً
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, Widget targetScreen, {Color? iconColor}) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.blueGrey.shade700),
      title: Text(title, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900)),
      dense: true, 
      onTap: () => _nav(context, targetScreen),
    );
  }

  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 5), 
      child: Text(title, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: primaryRed))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryRed, darkRed], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              accountName: Text("إدارة النظام (Admin)", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: Text("admin@dantecloud.local", style: GoogleFonts.cairo(fontSize: 12)),
              currentAccountPicture: Container(
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), 
                child: CircleAvatar(backgroundColor: primaryRed.withValues(alpha: 0.1), child: Icon(Icons.shield_rounded, size: 40, color: primaryRed))
              ),
            ),
            
            // ================== الفرع الأول: العمليات واللوجستيات ==================
            _buildDrawerSectionTitle("العمليات واللوجستيات الميدانية"),
            
            Container(
              color: Colors.amber.shade50.withValues(alpha: 0.5),
              child: _buildDrawerItem(
                context,
                Icons.history_edu_rounded, 
                "المراقبة الشاملة للتوجيه 📜", 
                const MasterTrackingScreen(),
                iconColor: Colors.orange.shade900
              ),
            ),
            _buildDrawerItem(context, Icons.dashboard_customize_rounded, "غرفة اللوجستيات والتجهيز", const LogisticsManagementScreen()),
            
            // 🔥 ربط الأجندة الجديدة هنا بألوان مميزة
            Container(
              color: Colors.purple.shade50.withValues(alpha: 0.5),
              child: _buildDrawerItem(
                context, 
                Icons.edit_calendar_rounded, 
                "المفكرة اللوجستية (Agenda) 📅", 
                const AgendaScreen(),
                iconColor: Colors.purple.shade700
              ),
            ),
            
            // 🔥 إعادة إضافة شاشة التجهيز والطباعة باسم جديد
            _buildDrawerItem(
              context, 
              Icons.assignment_turned_in_rounded, 
              "تجهيز شحنات اليوم (PDF) 🚛", 
              const DailyManifestScreen(),
              iconColor: Colors.brown.shade700
            ),
            
            _buildDrawerItem(context, Icons.fact_check_rounded, "مراجعة طلبات الزبائن", const CustomerOrdersReviewScreen()),
            const Divider(),

            // ================== الفرع الثاني: الأسطول والمالية ==================
            _buildDrawerSectionTitle("الأسطول والمحاسبة المالية"),
            
            _buildDrawerItem(context, Icons.airport_shuttle_rounded, "مراقبة الأسطول (الرادار)", const AdminFleetScreen()),
            _buildDrawerItem(context, Icons.attach_money_rounded, "تصفية الخزينة (NFC)", const FinancialSettlementScreen(), iconColor: Colors.teal.shade700),
            
            Container(
              color: Colors.green.shade50.withValues(alpha: 0.5),
              child: _buildDrawerItem(
                context,
                Icons.price_check_rounded, 
                "مراجعة مصاريف السائقين 💸", 
                const AdminExpenseReviewScreen(),
                iconColor: Colors.green.shade800
              ),
            ),
            _buildDrawerItem(context, Icons.receipt_long_rounded, "سجل الفواتير والمبيعات", const InvoicesScreen()),
            const Divider(),

            // ================== الفرع الثالث: إدارة الشركات ==================
            _buildDrawerSectionTitle("عملاء B2B والتسعير"),
            
            _buildDrawerItem(context, Icons.inventory_2_rounded, "إدارة المنتجات (المخزن)", const SalesManagementScreen()),
            Container(
              color: Colors.blue.shade50.withValues(alpha: 0.5),
              child: _buildDrawerItem(
                context,
                Icons.handshake_rounded, 
                "تسعير الشركات (B2B) 🏢", 
                const AdminB2BPricingScreen(),
                iconColor: Colors.blue.shade800
              ),
            ),
            _buildDrawerItem(context, Icons.local_offer_rounded, "عروض الأسعار الخاصة", const CustomerPricesScreen()),
            const Divider(),

            // ================== الفرع الرابع: إدارة النظام ==================
            _buildDrawerSectionTitle("إدارة النظام والمستخدمين"),
            _buildDrawerItem(context, Icons.group_rounded, "قائمة المستخدمين", const UserManagementScreen()),
            
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
              child: _buildDrawerItem(context, Icons.person_add_alt_1_rounded, "إضافة مستخدم جديد 👤", const AddUserScreen(), iconColor: Colors.blue.shade800),
            ),
            const Divider(),

            // ================== تسجيل الخروج ==================
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.logout_rounded, color: Colors.red)),
              title: Text("تسجيل الخروج", style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () async { 
                await ApiService.logout(); 
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false); 
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}