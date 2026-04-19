import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد مهم لفحص بيئة الويب
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';

// =========================================================================
// 1. الشاشة الرئيسية لسجل الفواتير والمبيعات (مكتملة ومبرمجة)
// =========================================================================
class SalesLedgerScreen extends StatefulWidget {
  const SalesLedgerScreen({super.key});

  @override
  State<SalesLedgerScreen> createState() => _SalesLedgerScreenState();
}

class _SalesLedgerScreenState extends State<SalesLedgerScreen> {
  final Color darkBlue = const Color(0xFF1E293B);
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color softBg = const Color(0xFFF8FAFC);

  bool _isLoading = true;
  List<dynamic> _allSettledOrders = [];
  List<dynamic> _filteredOrders = [];
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchSettledOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 📡 جلب الطلبيات المنجزة والمصفاة مالياً
  Future<void> _fetchSettledOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/settled-orders'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _allSettledOrders = data;
            _applySearch(); 
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        _showSnackBar("فشل في جلب الفواتير", Colors.red.shade800);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar("خطأ في الاتصال بالخادم", Colors.red.shade800);
    }
  }

  // 🔍 تطبيق البحث النصي
  void _applySearch() {
    if (_searchQuery.trim().isEmpty) {
      _filteredOrders = List.from(_allSettledOrders);
    } else {
      final searchLower = _searchQuery.trim().toLowerCase();
      _filteredOrders = _allSettledOrders.where((order) {
        final customerName = (order['customer_name'] ?? '').toString().toLowerCase();
        final trackingNum = (order['tracking_number'] ?? '').toString().toLowerCase();
        return customerName.contains(searchLower) || trackingNum.contains(searchLower);
      }).toList();
    }
    setState(() {});
  }

  // 🖨️ طباعة الفاتورة للزبون
  Future<void> _generateInvoicePdf(int orderId) async {
    final Uri url = Uri.parse('${ApiService.baseUrl}/admin/orders/$orderId/customer-receipt');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar("تعذر فتح ملف الطباعة", Colors.red);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء تحميل الفاتورة", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb; // 🔥 فحص الويب
    
    // حساب الإيرادات الإجمالية للفواتير المعروضة
    double totalRevenue = _filteredOrders.fold(0.0, (sum, item) => sum + (double.tryParse(item['cash_amount']?.toString() ?? '0') ?? 0.0));
    String formattedTotalRevenue = NumberFormat('#,##0.00').format(totalRevenue);

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: Text("سجل الفواتير والمبيعات 🧾", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: darkBlue,
        elevation: 0,
        centerTitle: true,
        // 🔥 إخفاء زر القائمة العلوية في المتصفح لتواجد الـ Sidebar
        leading: isDesktop ? const SizedBox.shrink() : null,
        actions: [
          IconButton(icon: const Icon(Icons.sync_rounded), onPressed: _fetchSettledOrders, tooltip: "تحديث السجل")
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 0), // مساحات للويب
        child: Column(
          children: [
            // 🔍 شريط البحث والإحصائيات السريعة
            Container(
              color: isDesktop ? softBg : Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _searchQuery = value;
                      _applySearch();
                    },
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: darkBlue),
                    decoration: InputDecoration(
                      hintText: "ابحث باسم الزبون أو رقم التتبع للحصول على فاتورته...",
                      hintStyle: GoogleFonts.cairo(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _applySearch();
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDesktop ? Colors.white : softBg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // شريط الإحصائيات (عدد الفواتير والإجمالي)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade100)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 18, color: Colors.teal.shade800),
                            const SizedBox(width: 8),
                            Text("الفواتير: ", style: GoogleFonts.cairo(fontSize: 13, color: Colors.teal.shade800, fontWeight: FontWeight.bold)),
                            Text("${_filteredOrders.length}", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: darkBlue)),
                          ],
                        ),
                        Row(
                          children: [
                            Text("إجمالي الإيرادات: ", style: GoogleFonts.cairo(fontSize: 13, color: Colors.teal.shade800, fontWeight: FontWeight.bold)),
                            Text("$formattedTotalRevenue دج", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 📋 قائمة الفواتير المكتملة
            Expanded(
              child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryRed))
                : RefreshIndicator(
                    color: primaryRed,
                    onRefresh: _fetchSettledOrders,
                    child: _filteredOrders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade300),
                              const SizedBox(height: 15),
                              Text("لا توجد فواتير مطابقة", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                            ],
                          ),
                        )
                      : isDesktop 
                          // 🔥 العرض المتجاوب للويب (شبكة)
                          ? GridView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3, 
                                crossAxisSpacing: 15,
                                mainAxisSpacing: 15,
                                childAspectRatio: 2.2, // نسبة العرض للارتفاع للبطاقة
                              ),
                              itemCount: _filteredOrders.length,
                              itemBuilder: (context, index) => SettledOrderCard(
                                order: _filteredOrders[index],
                                onGeneratePdf: _generateInvoicePdf,
                              ),
                            )
                          // 🔥 العرض الطولي للهواتف
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              itemCount: _filteredOrders.length,
                              itemBuilder: (context, index) {
                                return SettledOrderCard(
                                  order: _filteredOrders[index],
                                  onGeneratePdf: _generateInvoicePdf,
                                );
                              },
                            ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 2. كود البطاقة (SettledOrderCard) 
// =========================================================================
class SettledOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Function(int) onGeneratePdf;

  const SettledOrderCard({
    super.key,
    required this.order,
    required this.onGeneratePdf,
  });

  @override
  Widget build(BuildContext context) {
    final Color darkBlue = const Color(0xFF1E293B);

    final String rawTrackingNum = order['tracking_number']?.toString() ?? '...';
    final String displayTrackingNum = rawTrackingNum.length > 10 
        ? rawTrackingNum.substring(0, 10) 
        : rawTrackingNum;

    final double amountVal = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
    final String formattedAmount = NumberFormat('#,##0.00').format(amountVal);

    return Container(
      margin: EdgeInsets.only(bottom: kIsWeb ? 0 : 15), // إزالة الهامش في الويب لأن الجريد يتكفل به
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.check_circle_rounded, color: Colors.teal.shade600, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order['customer_name'] ?? 'مجهول', 
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: darkBlue),
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "ID: $displayTrackingNum", 
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$formattedAmount دج", 
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "مكتملة ومُصفاة", 
                      style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                    ),
                  )
                ],
              )
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  order['customer_address'] ?? 'غير محدد', 
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600), 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 35,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => onGeneratePdf(order['id'] ?? 0), 
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: Text("الفاتورة", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}