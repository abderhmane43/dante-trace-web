import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد مهم لفحص بيئة الويب
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nfc_manager/nfc_manager.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:intl/intl.dart'; 

import '../../services/api_service.dart';
import '../../widgets/admin/logistics/package_review_dialog.dart';
import '../../widgets/admin/logistics/logistics_dialogs.dart'; 

class LogisticsManagementScreen extends StatefulWidget {
  const LogisticsManagementScreen({super.key});

  @override
  State<LogisticsManagementScreen> createState() => _LogisticsManagementScreenState();
}

class _LogisticsManagementScreenState extends State<LogisticsManagementScreen> {
  final Color primaryOrange = Colors.orange.shade900;
  final Color darkBlue = const Color(0xFF1E293B);
  final Color backgroundGray = const Color(0xFFF4F7F9);

  bool _isLoading = true;
  List<dynamic> _pendingOrders = [];
  List<dynamic> _approvedOrders = [];
  List<dynamic> _allDrivers = [];

  DateTime _selectedDate = DateTime.now(); 

  @override
  void initState() {
    super.initState();
    _loadLogisticsData();
  }

  // ==========================================
  // 1. جلب البيانات
  // ==========================================
  Future<void> _loadLogisticsData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token'));
      final headers = {'Authorization': 'Bearer $token'};

      final results = await Future.wait([
        http.get(Uri.parse('${ApiService.baseUrl}/admin/pending-orders'), headers: headers),
        http.get(Uri.parse('${ApiService.baseUrl}/admin/approved-orders'), headers: headers),
        http.get(Uri.parse('${ApiService.baseUrl}/users/'), headers: headers),
      ]);

      if (mounted) {
        setState(() {
          if (results[0].statusCode == 200) _pendingOrders = jsonDecode(utf8.decode(results[0].bodyBytes));
          if (results[1].statusCode == 200) _approvedOrders = jsonDecode(utf8.decode(results[1].bodyBytes));
          if (results[2].statusCode == 200) {
            final users = jsonDecode(utf8.decode(results[2].bodyBytes));
            _allDrivers = users.where((u) => u['role'].toString().toLowerCase() == 'driver').toList();
          }
        });
      }
    } catch (e) {
      _showToast('❌ خطأ في الاتصال: $e', Colors.red);
      debugPrint("Error loading data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, List<dynamic>> _groupOrdersByDate(List<dynamic> orders) {
    Map<String, List<dynamic>> grouped = {};
    for (var order in orders) {
      String date = "غير محدد";
      if (order['scheduled_date'] != null) {
        date = order['scheduled_date'].toString().split('T')[0];
      } else if (order['created_at'] != null) {
        date = order['created_at'].toString().split('T')[0];
      }
      if (!grouped.containsKey(date)) grouped[date] = [];
      grouped[date]!.add(order);
    }
    return grouped;
  }

  // ==========================================
  // 2. محرك التوجيه (Pro Mode)
  // ==========================================
  Future<void> _executeManualDispatch(int orderId, String driverId) async {
    if (mounted && Navigator.canPop(context)) Navigator.pop(context); 
    
    _showLoadingOverlay();

    try {
      bool success = await ApiService.assignOrderToDriver(orderId, int.parse(driverId));
      
      if (mounted && Navigator.canPop(context)) Navigator.pop(context); 

      if (success) {
        await ApiService.updateOrderStatus(orderId, 'assigned');
        _showToast("✅ تم التوجيه بنجاح!", Colors.green.shade700);
        _loadLogisticsData(); 
      } else {
        _showToast("❌ فشل التوجيه اليدوي: تحقق من الصلاحيات", Colors.red);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _showToast("❌ حدث خطأ تقني: ${e.toString()}", Colors.red);
    }
  }

  void _showLoadingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  void _reviewAndAssignOrder(Map<String, dynamic> order) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PackageReviewDialog(
        order: order,
        fleet: _allDrivers, 
        onManualDispatch: (driverId) => _executeManualDispatch(order['id'], driverId),
        onNfcDispatch: () => _executeNfcHandshake(order['tracking_number'], order['id']),
      )
    ).then((_) => _loadLogisticsData());
  }

  void _showDispatchOptions(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // لجعل الإطار يظهر بشكل أجمل في الويب
      isScrollControlled: true,
      builder: (ctx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 45, height: 6, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 24),
                  Text("خيارات التوجيه السريع", style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: darkBlue)),
                  Text("طرد #${order['id']}", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
                  const SizedBox(height: 24),
                  _buildBottomSheetOption(
                    icon: Icons.nfc_rounded,
                    color: Colors.deepPurple,
                    title: "بصمة NFC",
                    subtitle: "مصافحة إلكترونية واستلام فيزيائي",
                    onTap: () { Navigator.pop(ctx); _executeNfcHandshake(order['tracking_number'], order['id']); }
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, thickness: 1)),
                  _buildBottomSheetOption(
                    icon: Icons.person_rounded,
                    color: primaryOrange,
                    title: "توجيه يدوي للأسطول",
                    subtitle: "إسناد مباشر لسائق محدد من القائمة",
                    onTap: () { Navigator.pop(ctx); _showManualDriverSelection(order); }
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildBottomSheetOption({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 28),
      ),
      title: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)),
      subtitle: Text(subtitle, style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
    );
  }

  void _showManualDriverSelection(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // دعم للويب
      isScrollControlled: true,
      builder: (ctx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  Container(width: 45, height: 6, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 24),
                  Text("اختر السائق المناسب", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _allDrivers.isEmpty 
                      ? _buildEmptyState("لا يوجد سائقين متاحين حالياً", Icons.groups_rounded)
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _allDrivers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final driver = _allDrivers[index];
                            return InkWell(
                              onTap: () => _executeManualDispatch(order['id'], driver['id'].toString()),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.blue.shade50, 
                                      child: Icon(Icons.delivery_dining_rounded, color: Colors.blue.shade700, size: 24)
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(driver['username'] ?? 'سائق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)),
                                          Text("ID: ${driver['id']}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                                      child: Text("إسناد", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12, color: darkBlue)),
                                    )
                                  ],
                                ),
                              ),
                            );
                          }
                        )
                  )
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  void _executeNfcHandshake(String trackingNum, int orderId) { 
    if (kIsWeb) {
      _showToast("خاصية NFC تتطلب تطبيق الهاتف. الرجاء التوجيه اليدوي للأسطول.", Colors.orange);
      return;
    }
    _showToast("قم بتقريب البطاقة من الهاتف الآن...", Colors.blue); 
  }

  void _showToast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ==========================================
  // 3. بناء الواجهة الرئيسية
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb; // 🔥 فحص بيئة الويب

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: backgroundGray,
        appBar: AppBar(
          title: Text("غرفة العمليات اللوجستية", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: primaryOrange, foregroundColor: Colors.white, elevation: 0,
          centerTitle: true,
          // 🔥 إخفاء القائمة العلوية في الكمبيوتر
          leading: isDesktop ? const SizedBox.shrink() : null,
          bottom: TabBar(
            indicatorColor: Colors.white, indicatorWeight: 4, indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
            unselectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: const [
              Tab(icon: Icon(Icons.assignment_turned_in_rounded), text: "بانتظار الاعتماد"), 
              Tab(icon: Icon(Icons.alt_route_rounded), text: "جاهزة للتوجيه")
            ],
          ),
        ),
        body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: primaryOrange))
          : TabBarView(
              children: [
                _buildTabContent(_pendingOrders, "لا توجد طلبات جديدة بانتظار الاعتماد", Icons.check_circle_outline_rounded, true, isDesktop),
                _buildProfessionalRoutingTab(_approvedOrders, isDesktop), 
              ],
            ),
      ),
    );
  }

  Widget _buildTabContent(List<dynamic> orders, String emptyMsg, IconData emptyIcon, bool isPendingTab, bool isDesktop) {
    if (orders.isEmpty) return _buildEmptyState(emptyMsg, emptyIcon);
    return RefreshIndicator(
      color: primaryOrange,
      onRefresh: _loadLogisticsData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 16, vertical: 16), // مساحات الويب
        child: _buildOrderList(orders, isPendingTab, isDesktop),
      ),
    );
  }

  Widget _buildProfessionalRoutingTab(List<dynamic> orders, bool isDesktop) {
    var grouped = _groupOrdersByDate(orders);
    String formattedSelectedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    List<dynamic> currentOrders = grouped[formattedSelectedDate] ?? [];
    
    double dailyTotal = 0;
    for (var o in currentOrders) {
      dailyTotal += double.tryParse(o['cash_amount']?.toString() ?? '0') ?? 0.0;
    }
    String formattedDailyTotal = NumberFormat('#,##0.00').format(dailyTotal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDateHeader(formattedSelectedDate, isDesktop),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 16),
          child: Row(
            children: [
              _buildSummaryCard("الطرود المتاحة", "${currentOrders.length}", Icons.inventory_2_rounded, primaryOrange),
              const SizedBox(width: 12),
              _buildSummaryCard("قيمة العهدة", "$formattedDailyTotal دج", Icons.account_balance_wallet_rounded, Colors.green.shade700),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            color: primaryOrange,
            onRefresh: _loadLogisticsData,
            child: currentOrders.isEmpty 
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.15), 
                  _buildEmptyState("لا توجد طرود جاهزة للتوجيه في هذا اليوم", Icons.event_busy_rounded)
                ]
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 16, vertical: 8),
                child: _buildOrderList(currentOrders, false, isDesktop),
              ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10), 
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), 
              child: Icon(icon, color: color, size: 22)
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: darkBlue)),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(String date, bool isDesktop) {
    return Container(
      margin: EdgeInsets.fromLTRB(isDesktop ? 60 : 16, 16, isDesktop ? 60 : 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [darkBlue, const Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: darkBlue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("تاريخ التوجيه الميداني", style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(date, style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _showFullCalendarModal,
            icon: Icon(Icons.edit_calendar_rounded, color: darkBlue, size: 18),
            label: Text("تغيير", style: GoogleFonts.cairo(color: darkBlue, fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, 
              elevation: 0, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
            ),
          )
        ],
      ),
    );
  }

  // 🔥 الترصيص الاحترافي: استبدال الـ DataTable بقائمة بطاقات عصرية متجاوبة للويب
  Widget _buildOrderList(List<dynamic> orders, bool isPendingTab, bool isDesktop) {
    return isDesktop
        ? GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 2.2, 
            ),
            itemCount: orders.length,
            itemBuilder: (context, index) => _buildOrderCard(orders[index], isPendingTab),
          )
        : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildOrderCard(orders[index], isPendingTab),
          );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, bool isPendingTab) {
    final double rawAmount = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
    final String formattedAmount = NumberFormat('#,##0.00').format(rawAmount);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصف الأول: رقم الطرد والمبلغ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: darkBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.inventory_2_rounded, size: 18, color: darkBlue),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("#${order['id']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 16)),
                        Text(order['tracking_number']?.toString().substring(0, 10) ?? '', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                  child: Text("$formattedAmount دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 14)),
                ),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, thickness: 1)),
            
            // الصف الثاني: اسم الزبون
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(order['customer_name'] ?? 'مجهول', style: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 14, color: darkBlue), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const Spacer(), 
            
            // الصف الثالث: الأزرار والعمليات
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isPendingTab)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: Text("طباعة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueGrey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onPressed: () async {
                      final Uri url = Uri.parse('${ApiService.baseUrl}/admin/orders/${order['id']}/picking-list');
                      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                    },
                  ),
                if (isPendingTab) const SizedBox(width: 8),
                if (isPendingTab)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.remove_red_eye_rounded, size: 16, color: Colors.white),
                      label: Text("مراجعة واعتماد", style: GoogleFonts.cairo(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryOrange,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _reviewAndAssignOrder(order),
                    ),
                  ),
                if (!isPendingTab)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      label: Text("توجيه سريع للطرد", style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _showDispatchOptions(order),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFullCalendarModal() {
    showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: primaryOrange, 
            onPrimary: Colors.white, 
            surface: Colors.white, 
            onSurface: darkBlue,
          ), 
          datePickerTheme: DatePickerThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        child: child!,
      ),
    ).then((date) {
      if (date != null) setState(() => _selectedDate = date);
    });
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(icon, size: 60, color: Colors.grey.shade400)
          ), 
          const SizedBox(height: 16), 
          Text(msg, style: GoogleFonts.cairo(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.bold))
        ]
      )
    );
  }
}