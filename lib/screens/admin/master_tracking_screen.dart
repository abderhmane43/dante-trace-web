import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد فحص بيئة الويب
import 'package:flutter/services.dart'; // 🔥 للنسخ إلى الحافظة (Clipboard)
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; 
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../widgets/admin/shipment_journey_timeline.dart';
import '../../widgets/admin/verify_payment_dialog.dart';
import '../../widgets/master_pin_dialog.dart'; // 🔥 استيراد نافذة الحارس (الرقم السري)

class MasterTrackingScreen extends StatefulWidget {
  const MasterTrackingScreen({super.key});

  @override
  State<MasterTrackingScreen> createState() => _MasterTrackingScreenState();
}

class _MasterTrackingScreenState extends State<MasterTrackingScreen> {
  // 🎨 الألوان (Pro Mode)
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B);
  final Color softBg = const Color(0xFFF8FAFC);

  bool _isLoading = true;
  List<dynamic> _allOrders = [];
  List<dynamic> _filteredOrders = [];
  
  String _searchQuery = '';
  String _selectedFilter = 'all'; 

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAllOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 📡 جلب جميع الطلبيات من السيرفر (بدون قيود)
  Future<void> _fetchAllOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/all-orders'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            // ترتيب بحيث تظهر الطلبيات التي تحتاج مراجعة في الأعلى
            data.sort((a, b) {
              if (a['payment_status'] == 'pending_admin_verification' && b['payment_status'] != 'pending_admin_verification') return -1;
              if (b['payment_status'] == 'pending_admin_verification' && a['payment_status'] != 'pending_admin_verification') return 1;
              return (b['id'] as int).compareTo(a['id'] as int);
            });
            
            _allOrders = data;
            _applyFilters(); 
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching all orders: $e");
    }
  }

  // 🔍 تطبيق البحث والفلترة
  void _applyFilters() {
    List<dynamic> temp = _allOrders;

    // 1. تطبيق فلتر الحالة
    if (_selectedFilter != 'all') {
      temp = temp.where((order) {
        final status = order['delivery_status']?.toString() ?? '';
        final paymentStatus = order['payment_status']?.toString() ?? '';
        
        if (_selectedFilter == 'pending_group') {
          return status == 'pending' || status == 'pending_approval' || status == 'approved';
        } else if (_selectedFilter == 'active_group') {
          return status == 'assigned' || status == 'picked_up' || status == 'in_transit';
        } else if (_selectedFilter == 'delivered_group') {
          // لا تشمل الطلبيات التي صرح بها الزبون وتنتظر المراجعة هنا
          return (status == 'delivered' || status == 'delivered_unpaid' || status == 'assigned_to_collector') 
                 && paymentStatus != 'pending_admin_verification';
        } else if (_selectedFilter == 'settled_group') {
          return status == 'settled_with_collector' || status == 'settled';
        } else if (_selectedFilter == 'verification_group') {
          // 🔥 فلتر جديد خاص بالمراجعات المالية فقط
          return paymentStatus == 'pending_admin_verification';
        }
        return true;
      }).toList();
    }

    // 2. تطبيق البحث النصي (مُحسن)
    if (_searchQuery.trim().isNotEmpty) {
      final searchLower = _searchQuery.trim().toLowerCase();
      temp = temp.where((order) {
        final customerName = (order['customer_name'] ?? '').toString().toLowerCase();
        final trackingNum = (order['tracking_number'] ?? '').toString().toLowerCase();
        
        return customerName.contains(searchLower) || trackingNum.contains(searchLower);
      }).toList();
    }

    setState(() {
      _filteredOrders = temp;
    });
  }

  // 📜 فتح نافذة السجل الزمني التفصيلي
  void _openJourneyTimeline(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ShipmentJourneyTimeline(order: order),
      ),
    );
  }

  // 💬 فتح واتساب للزبون مباشرة
  Future<void> _launchWhatsApp(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), ''); 
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '213${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('213')) {
      cleanPhone = '213$cleanPhone'; 
    }

    final Uri whatsappUrl = Uri.parse("whatsapp://send?phone=$cleanPhone");
    final Uri webUrl = Uri.parse("https://wa.me/$cleanPhone");
    
    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar("تعذر فتح واتساب. تأكد من تثبيت التطبيق.", Colors.red);
      }
    } catch (e) {
      _showSnackBar("تعذر فتح واتساب.", Colors.red);
    }
  }

  // 🗑️ 🔥 دالة الحذف النهائي المباشر من الرادار (محمية بالكود السري 2026) 🔥
  Future<void> _deleteOrder(int orderId, String trackingNum) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text("تأكيد الحذف", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
          ],
        ),
        content: Text("هل أنت متأكد من حذف الطلبية ($trackingNum) نهائياً؟\nسيتم سحبها من هاتف السائق فوراً.", style: GoogleFonts.cairo(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("نعم، احذفها", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ]
      )
    );

    if (confirm != true) return;

    // 🔥 فتح نافذة الحارس لطلب الرمز السري (2026)
    String? pin = await MasterPinDialog.show(context);

    // إذا أدخل المدير الرمز السري
    if (pin != null && pin.isNotEmpty) {
      // إظهار التحميل
      showDialog(context: context, barrierDismissible: false, builder: (loadingCtx) => Center(child: CircularProgressIndicator(color: primaryRed)));

      try {
        // 🔥 إرسال طلب الحذف عبر خدمة ApiService المخصصة لضمان إرسال الـ PIN للسيرفر
        final result = await ApiService.deleteShipment(orderId, pin);

        if (!mounted) return;
        Navigator.pop(context); // إغلاق نافذة التحميل

        if (result['success'] == true) {
          _showSnackBar("✅ ${result['message'] ?? 'تم الحذف بنجاح'}", Colors.green.shade700);
          _fetchAllOrders(); // تحديث الرادار
        } else {
          _showSnackBar("❌ ${result['message'] ?? 'فشل الحذف، تأكد من الكود السري'}", Colors.red.shade800);
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        _showSnackBar("❌ حدث خطأ في الاتصال بالخادم", Colors.red.shade800);
      }
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 فحص بيئة العمل (ويب/كمبيوتر أم هاتف)
    final isDesktop = kIsWeb; 

    // 🔥 حساب الإجمالي المالي للطلبيات المفلترة
    double totalFilteredValue = _filteredOrders.fold(0.0, (sum, item) => sum + (double.tryParse(item['cash_amount']?.toString() ?? '0') ?? 0.0));
    String formattedTotalValue = NumberFormat('#,##0.00').format(totalFilteredValue);

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: Text("برج المراقبة الشامل 🛰️", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: darkBlue),
        centerTitle: true,
        // 🔥 إخفاء القائمة في حال فتح من الكمبيوتر لتواجد الـ Sidebar
        leading: isDesktop ? const SizedBox.shrink() : null, 
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            onPressed: _fetchAllOrders,
            tooltip: "تحديث البيانات",
          )
        ],
      ),
      body: Padding(
        // 🔥 إضافة حواف كبيرة في حالة الحاسوب لتوسيط المحتوى وراحة العين
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔍 شريط البحث
            Container(
              color: isDesktop ? softBg : Colors.white, 
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  _searchQuery = value;
                  _applyFilters();
                },
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: darkBlue),
                decoration: InputDecoration(
                  hintText: "ابحث باسم الزبون أو رقم التتبع...",
                  hintStyle: GoogleFonts.cairo(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.normal),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _applyFilters();
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
            ),

            // 🏷️ فلاتر الحالات (Chips)
            Container(
              color: isDesktop ? softBg : Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'الكل', Icons.all_inbox_rounded),
                    _buildFilterChip('verification_group', 'مراجعة مالية 💳', Icons.receipt_long_rounded), 
                    _buildFilterChip('pending_group', 'قيد الانتظار', Icons.hourglass_empty_rounded),
                    _buildFilterChip('active_group', 'في الميدان', Icons.local_shipping_rounded),
                    _buildFilterChip('delivered_group', 'تم التسليم', Icons.where_to_vote_rounded),
                    _buildFilterChip('settled_group', 'مصفاة مالياً', Icons.verified_rounded),
                  ],
                ),
              ),
            ),

            // 📊 شريط العداد المالي والإحصائيات الذكية
            if (!_isLoading)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 15, 20, 5),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.shade100)
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics_outlined, size: 18, color: darkBlue),
                        const SizedBox(width: 8),
                        Text("العدد: ", style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                        Text("${_filteredOrders.length}", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: primaryRed)),
                      ],
                    ),
                    Row(
                      children: [
                        Text("القيمة: ", style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                        Text("$formattedTotalValue دج", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                      ],
                    ),
                  ],
                ),
              ),

            // 📋 قائمة الطلبيات
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryRed))
                  : RefreshIndicator(
                      onRefresh: _fetchAllOrders,
                      color: primaryRed,
                      child: _filteredOrders.isEmpty
                          ? _buildEmptyState()
                          : isDesktop 
                              // 🔥 التصميم الجديد (Wrap) لحل مشكلة التداخل في المتصفح 🔥
                              ? SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                                  physics: const BouncingScrollPhysics(),
                                  child: Wrap(
                                    spacing: 15, // المسافة الأفقية بين الكروت
                                    runSpacing: 15, // المسافة العمودية بين الكروت
                                    children: _filteredOrders.map((order) {
                                      // حساب عرض الكارت بناءً على حجم الشاشة (ليكون لدينا 3 كروت في السطر تقريباً)
                                      return SizedBox(
                                        width: (MediaQuery.of(context).size.width - 200) / 3,
                                        child: _buildOrderCard(order, isDesktop: true), // تمرير isDesktop لمنع الهوامش الزائدة
                                      );
                                    }).toList(),
                                  ),
                                )
                              // تصميم القائمة (ListView) للموبايل يظل كما هو
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                  itemCount: _filteredOrders.length,
                                  itemBuilder: (context, index) => _buildOrderCard(_filteredOrders[index]),
                                ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- مكونات الواجهة ---

  Widget _buildFilterChip(String filterValue, String label, IconData icon) {
    final bool isSelected = _selectedFilter == filterValue;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
        backgroundColor: filterValue == 'verification_group' ? Colors.orange.shade50 : Colors.grey.shade100, 
        selectedColor: filterValue == 'verification_group' ? Colors.orange.shade700 : darkBlue,
        side: BorderSide(color: isSelected ? (filterValue == 'verification_group' ? Colors.orange.shade700 : darkBlue) : Colors.grey.shade200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : (filterValue == 'verification_group' ? Colors.orange.shade700 : Colors.grey.shade600)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (filterValue == 'verification_group' ? Colors.orange.shade800 : Colors.grey.shade700))),
          ],
        ),
        onSelected: (bool selected) {
          setState(() {
            _selectedFilter = filterValue;
            _applyFilters();
          });
        },
      ),
    );
  }

  // 🔥 إضافة متغير isDesktop للتحكم بالهوامش
  Widget _buildOrderCard(Map<String, dynamic> order, {bool isDesktop = false}) {
    final String status = order['delivery_status']?.toString() ?? 'pending';
    final String paymentStatus = order['payment_status']?.toString() ?? 'unpaid';
    final String trackingNum = order['tracking_number']?.toString() ?? '-';
    final String customerName = order['customer_name']?.toString() ?? 'مجهول';
    final String customerPhone = order['customer_phone']?.toString() ?? '';
    
    final bool needsPaymentVerification = (paymentStatus == 'pending_admin_verification');
    
    String dateStr = "غير محدد";
    if (order['created_at'] != null) {
      dateStr = order['created_at'].toString().split('T')[0];
    }

    final double amountVal = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
    final String formattedAmount = NumberFormat('#,##0.00').format(amountVal);

    Color statusColor;
    String statusLabel;

    if (needsPaymentVerification) {
      statusColor = Colors.orange.shade700; statusLabel = 'تأكيد الدفع ⏳';
    } else if (status == 'delivered' && paymentStatus == 'awaiting_customer_payment') {
      statusColor = Colors.red.shade600; statusLabel = 'ينتظر الزبون';
    } else if (status.contains('pending') || status == 'approved') {
      statusColor = Colors.orange.shade600; statusLabel = 'قيد المعالجة';
    } else if (status == 'assigned' || status == 'picked_up' || status == 'in_transit') {
      statusColor = Colors.blue.shade700; statusLabel = 'في الميدان';
    } else if (status == 'delivered') {
      statusColor = Colors.indigo.shade500; statusLabel = 'عهدة السائق 💵';
    } else if (status == 'delivered_unpaid' || status == 'assigned_to_collector') {
      statusColor = Colors.purple.shade600; statusLabel = 'للتحصيل/آجل';
    } else if (status.contains('settled')) {
      statusColor = Colors.teal.shade700; statusLabel = 'مصفاة للخزينة';
    } else {
      statusColor = Colors.grey.shade700; statusLabel = status;
    }

    return Container(
      // 🔥 إزالة الهامش السفلي في حالة الكمبيوتر لأن الـ Wrap يتكفل بالمساحات
      margin: EdgeInsets.only(bottom: isDesktop ? 0 : 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: needsPaymentVerification ? Colors.orange.shade300 : Colors.grey.shade200, width: needsPaymentVerification ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: needsPaymentVerification ? Colors.orange.shade50 : darkBlue.withOpacity(0.05), shape: BoxShape.circle),
              child: Icon(needsPaymentVerification ? Icons.receipt_long_rounded : Icons.local_shipping_outlined, color: needsPaymentVerification ? Colors.orange.shade800 : darkBlue, size: 20),
            ),
            const SizedBox(width: 15),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(customerName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: darkBlue), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text("$formattedAmount دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 14)),
                    ],
                  ),
                  
                  InkWell(
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: trackingNum));
                      _showSnackBar("تم نسخ رقم التتبع", Colors.green);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Flexible(child: Text("ID: $trackingNum", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(dateStr, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildStatusBadge(statusLabel, statusColor),
                      
                      if (needsPaymentVerification)
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => VerifyPaymentDialog(
                                order: order,
                                onSuccess: () {
                                  _showSnackBar("✅ تم تأكيد الدفع بنجاح!", Colors.green);
                                  _fetchAllOrders();
                                },
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade300)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_user_rounded, color: Colors.green, size: 14),
                                const SizedBox(width: 4),
                                Text("مراجعة الدفع", style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800, height: 1)),
                              ],
                            ),
                          ),
                        ),
                        
                      if (customerPhone.isNotEmpty && !needsPaymentVerification)
                        _buildActionBtn(Icons.chat_bubble_outline_rounded, Colors.green.shade600, Colors.green.shade50, () => _launchWhatsApp(customerPhone)),
                        
                      _buildActionBtn(Icons.history_edu_rounded, primaryRed, primaryRed.withOpacity(0.05), () => _openJourneyTimeline(order)),
                      
                      // 🗑️ زر الحذف
                      _buildActionBtn(Icons.delete_outline_rounded, Colors.red, Colors.red.shade50, () => _deleteOrder(order['id'], trackingNum)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, Color iconColor, Color bgColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, size: 8, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: color, height: 1)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text("لا توجد طلبيات مطابقة للبحث", style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}