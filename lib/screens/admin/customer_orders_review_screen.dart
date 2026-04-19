import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد مهم لفحص بيئة الويب
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; 
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';

// 🔥 تم تغيير مسار الاستيراد هنا ليشير للملف الجديد!
import '../../widgets/admin/advanced_split_dialog.dart';

class CustomerOrdersReviewScreen extends StatefulWidget {
  const CustomerOrdersReviewScreen({super.key});

  @override
  State<CustomerOrdersReviewScreen> createState() => _CustomerOrdersReviewScreenState();
}

class _CustomerOrdersReviewScreenState extends State<CustomerOrdersReviewScreen> {
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B);
  final Color pendingPurple = const Color(0xFF9C27B0); 
  final Color successGreen = const Color(0xFF2E7D32);
  final Color bgGray = const Color(0xFFF4F7F9); 
  
  List<dynamic> pendingOrders = [];
  List<dynamic> _availableDrivers = []; 
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // 📡 1. جلب الطلبيات المعلقة وقائمة السائقين
  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token'));
      final headers = {'Authorization': 'Bearer $token'};

      final results = await Future.wait([
        http.get(Uri.parse('${ApiService.baseUrl}/admin/pending-orders'), headers: headers),
        http.get(Uri.parse('${ApiService.baseUrl}/users/'), headers: headers), // جلب السائقين
      ]);

      if (mounted) {
        setState(() {
          if (results[0].statusCode == 200) {
            List<dynamic> allPending = jsonDecode(utf8.decode(results[0].bodyBytes));
            
            // 🔥 الفلترة الذكية المحدثة (لإبقاء الطلبية الأم وإخفاء المجدول فقط)
            pendingOrders = allPending.where((order) {
              bool isSubOrder = order['master_shipment_id'] != null; 
              bool hasDate = order['scheduled_date'] != null; 
              bool isMaster = order['is_master'] == true; 
              double remainingCash = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
              
              if (isSubOrder) return false;
              if (hasDate && !isMaster) return false;
              if (isMaster && remainingCash <= 0) return false;

              return true; 
            }).toList();
            
            pendingOrders.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
          }
          if (results[1].statusCode == 200) {
            final users = jsonDecode(utf8.decode(results[1].bodyBytes));
            _availableDrivers = users.where((u) => u['role'] == 'driver').toList();
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      _showSnackBar("فشل في تحديث البيانات، تحقق من الاتصال", Colors.red.shade800);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _launchWhatsApp(String phone, String message) async {
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), ''); 
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '213${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('213')) {
      cleanPhone = '213$cleanPhone'; 
    }

    final Uri whatsappUrl = Uri.parse("whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}");
    final Uri webUrl = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
    
    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar("تعذر فتح واتساب. تأكد من تثبيت التطبيق.", Colors.red);
      }
    } catch (e) {
      debugPrint("WhatsApp Launch Error: $e");
      _showSnackBar("تعذر فتح واتساب.", Colors.red);
    }
  }

  // =========================================================================
  // ✂️ 2. نافذة التقسيم والجدولة الذكية
  // =========================================================================
  void _showSplitDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AdvancedSplitDialog(
        order: order,
        onSuccess: (String whatsappMsg, String phone) async {
          _showSnackBar("✅ تم التقسيم! جاري فتح واتساب لإبلاغ الزبون...", Colors.green.shade700);
          _fetchData();
          if (phone.isNotEmpty) {
            await _launchWhatsApp(phone, whatsappMsg);
          }
        },
        onError: () => _showSnackBar("❌ حدث خطأ أثناء التقسيم!", Colors.red.shade800),
      )
    );
  }

  // =========================================================================
  // 🗑️ 3. دالة الحذف النهائي للطلبية
  // =========================================================================
  Future<void> _deleteOrder(int orderId, BuildContext parentDialogCtx) async {
    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text("حذف نهائي للطلبية", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
          ],
        ),
        content: Text("هل أنت متأكد من حذف هذه الطلبية نهائياً من النظام؟\nهذا الإجراء لا يمكن التراجع عنه.", style: GoogleFonts.cairo(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(confirmCtx), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(confirmCtx);
              showDialog(context: context, barrierDismissible: false, builder: (loadingCtx) => const Center(child: CircularProgressIndicator(color: Colors.red)));
              
              try {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('auth_token') ?? '';
                final response = await http.delete(
                  Uri.parse('${ApiService.baseUrl}/admin/shipments/$orderId'),
                  headers: {'Authorization': 'Bearer $token'},
                );
                
                if (!mounted) return;
                Navigator.pop(context); 
                
                if (response.statusCode == 200) {
                  Navigator.pop(parentDialogCtx);
                  _showSnackBar("✅ تم مسح الطلبية من النظام نهائياً 🗑️", Colors.green.shade700);
                  _fetchData(); 
                } else {
                  _showSnackBar("❌ فشل الحذف، راجع الصلاحيات", Colors.red.shade800);
                }
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                _showSnackBar("❌ حدث خطأ في الاتصال بالخادم", Colors.red.shade800);
              }
            },
            child: Text("نعم، احذفها", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ]
      )
    );
  }

  // =========================================================================
  // 🚚 4. الإسناد السريع مع ميزة التخطي (Bypass NFC) وإرسال واتساب للسائق
  // =========================================================================
  void _showAssignBottomSheet(int shipmentId, String customerName, BuildContext parentDialogCtx) {
    int? selectedDriverId;
    bool isAssigning = false;
    bool bypassNfc = true; 

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      backgroundColor: Colors.white,
      isScrollControlled: true, 
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, 
              top: 20, left: 20, right: 20
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, color: primaryRed, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text("اعتماد وإسناد فوري", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text("اختر السائق الذي سيتولى توصيل طلبية الزبون: $customerName", style: GoogleFonts.cairo(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 15),

                Container(
                  decoration: BoxDecoration(
                    color: bypassNfc ? Colors.orange.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: bypassNfc ? Colors.orange.shade300 : Colors.grey.shade200, width: 1.5)
                  ),
                  child: CheckboxListTile(
                    value: bypassNfc,
                    activeColor: Colors.orange.shade800,
                    title: Text("تخطي تأكيد استلام السائق (بدون NFC)", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: darkBlue)),
                    subtitle: Text("سيتم تحويل الطرد مباشرة إلى حالة 'في الطريق'", style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade600)),
                    onChanged: (val) => setModalState(() => bypassNfc = val ?? false),
                  ),
                ),
                const SizedBox(height: 15),
                
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: "السائق المتاح",
                    labelStyle: GoogleFonts.cairo(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.person_pin_circle_rounded, color: Colors.blue.shade700),
                    filled: true,
                    fillColor: Colors.blue.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                  items: _availableDrivers.map<DropdownMenuItem<int>>((d) {
                    return DropdownMenuItem(
                      value: d['id'], 
                      child: Text("${d['username']} ${d['first_name'] != null ? '(${d['first_name']})' : ''}", style: GoogleFonts.cairo(fontWeight: FontWeight.bold))
                    );
                  }).toList(),
                  onChanged: (val) => setModalState(() => selectedDriverId = val),
                ),
                
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    onPressed: (selectedDriverId == null || isAssigning) ? null : () async {
                      setModalState(() => isAssigning = true);
                      
                      bool successAssign = await ApiService.assignOrderToDriver(shipmentId, selectedDriverId!, skipNfc: bypassNfc);
                      
                      if (!mounted) return;
                      
                      if (successAssign) {
                        if (bypassNfc) {
                          await ApiService.updateOrderStatus(shipmentId, 'picked_up');
                        } else {
                          await ApiService.updateOrderStatus(shipmentId, 'assigned');
                        }

                        // 🔥 الإضافة الجديدة: جلب بيانات السائق وإرسال رسالة واتساب
                        final selectedDriver = _availableDrivers.firstWhere((d) => d['id'] == selectedDriverId);
                        String driverPhone = selectedDriver['phone'] ?? "";
                        String driverName = selectedDriver['first_name'] ?? selectedDriver['username'];
                        
                        if (driverPhone.isNotEmpty) {
                          String driverMsg = bypassNfc 
                            ? "مرحباً $driverName، تم إسناد طلبية الزبون *$customerName* لك بنجاح. يرجى البدء في عملية التوصيل فوراً 🚚."
                            : "مرحباً $driverName، تم تعيينك لتوصيل طلبية الزبون *$customerName*. يرجى الالتحاق بالمخزن لتأكيد الاستلام عبر NFC للبدء 📦.";
                          
                          await _launchWhatsApp(driverPhone, driverMsg);
                        }

                        if (!mounted) return;
                        if (Navigator.canPop(ctx)) Navigator.pop(ctx); 
                        if (Navigator.canPop(parentDialogCtx)) Navigator.pop(parentDialogCtx); 
                        
                        _showSnackBar("تم الإسناد وإبلاغ السائق بنجاح 🚀", Colors.green.shade700);
                        _fetchData(); 
                      } else {
                        if (Navigator.canPop(ctx)) Navigator.pop(ctx); 
                        _showSnackBar("حدث خطأ أثناء إسناد الطلبية", Colors.red.shade800);
                        setState(() => isLoading = false);
                      }
                    },
                    child: isAssigning 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text("اعتماد وإرسال للسائق", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        }
      ),
    );
  }

  // 📝 5. نافذة تفاصيل الطلبية
  void _showOrderDetails(Map<String, dynamic> order) {
    String status = order['delivery_status'] ?? 'pending';
    String approvalStatus = order['customer_approval_status'] ?? 'not_required';
    bool isPendingApproval = status == 'pending_approval' && approvalStatus == 'pending';

    final double orderAmount = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
    final String formattedOrderAmount = NumberFormat('#,##0.00').format(orderAmount);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog( 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.all(0),
        title: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: darkBlue, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("تفاصيل الطلبية", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
              
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent), 
                    tooltip: "مسح الطلبية نهائياً",
                    onPressed: () => _deleteOrder(order['id'], dialogCtx),
                  ),
                  if (!isPendingApproval && status == 'pending')
                    IconButton(
                      icon: const Icon(Icons.content_cut_rounded, color: Colors.white), 
                      tooltip: "تقسيم الطلبية (مخطط لوجستي)",
                      onPressed: () {
                        Navigator.pop(dialogCtx); 
                        _showSplitDialog(order); 
                      }
                    ),
                ],
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.storefront_rounded, color: Colors.grey.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text("الزبون: ${order['customer_name']}", style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
                ],
              ),
              const Divider(height: 30),
              Text("📦 المنتجات المطلوبة:", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              ...(order['items'] as List).map((i) {
                double itemPrice = double.tryParse(i['price']?.toString() ?? '0') ?? 0.0;
                String priceStr = itemPrice > 0 ? " | ${NumberFormat('#,##0.00').format(itemPrice)} دج" : "";
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text("• ${i['name']}$priceStr", style: GoogleFonts.cairo(fontWeight: FontWeight.w600))),
                      const SizedBox(width: 10),
                      Text("x${i['qty']}", style: GoogleFonts.poppins(color: primaryRed, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("إجمالي الدفع:", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  Text("$formattedOrderAmount دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx), 
            child: Text("إغلاق", style: GoogleFonts.cairo(color: Colors.grey.shade700, fontWeight: FontWeight.bold))
          ),
          
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isPendingApproval ? Colors.grey : successGreen, 
              foregroundColor: Colors.white, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            icon: const Icon(Icons.assignment_turned_in_rounded, size: 18),
            label: Text(isPendingApproval ? "بانتظار الزبون" : "اعتماد وتعيين 🚚", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            onPressed: isPendingApproval 
                ? null 
                : () => _showAssignBottomSheet(order['id'], order['customer_name'], dialogCtx),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    String status = order['delivery_status'] ?? 'pending';
    String approvalStatus = order['customer_approval_status'] ?? 'not_required';
    
    bool isPendingApproval = status == 'pending_approval' && approvalStatus == 'pending';

    final double amount = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
    final String formattedAmount = NumberFormat('#,##0.00').format(amount);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPendingApproval ? pendingPurple : Colors.grey.shade200, width: isPendingApproval ? 1.5 : 1),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: isPendingApproval ? pendingPurple.withOpacity(0.1) : Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.receipt_long_rounded, color: isPendingApproval ? pendingPurple : darkBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order['customer_name'] ?? 'مجهول', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: darkBlue)),
                    Text("المبلغ: $formattedAmount دج", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: isPendingApproval ? pendingPurple.withOpacity(0.1) : Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  isPendingApproval ? "مُعلقة (للزبون)" : "جديدة للفرز", 
                  style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: isPendingApproval ? pendingPurple : Colors.orange.shade800)
                ),
              )
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 5),
              Expanded(child: Text(order['customer_address'] ?? 'غير محدد', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600))),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: darkBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10)
              ),
              onPressed: () => _showOrderDetails(order),
              child: Text("مراجعة الطلبية", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 فحص هل يعمل التطبيق على المتصفح/الحاسوب
    final isDesktop = kIsWeb; 

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("غرفة العمليات المبدئية 📝", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 18)), 
        backgroundColor: Colors.white, 
        elevation: 0, 
        centerTitle: true,
        // 🔥 إخفاء القائمة/زر الرجوع إذا كان في الحاسوب
        leading: isDesktop ? const SizedBox.shrink() : null,
        iconTheme: IconThemeData(color: darkBlue),
      ),
      body: isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryRed))
        : pendingOrders.isEmpty
            ? Center(child: Text("صندوق الوارد نظيف تماماً ✨", style: GoogleFonts.cairo(color: Colors.grey, fontSize: 16)))
            : RefreshIndicator(
                onRefresh: _fetchData,
                color: primaryRed,
                // 🔥 تصميم ذكي (Responsive) للشبكة
                child: isDesktop 
                  ? GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, // عرض 3 بطاقات في السطر للحاسوب
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 1.6, // نسبة عرض البطاقة
                      ),
                      itemCount: pendingOrders.length,
                      itemBuilder: (context, index) => _buildOrderCard(pendingOrders[index]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(15),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: pendingOrders.length,
                      itemBuilder: (context, index) => _buildOrderCard(pendingOrders[index]),
                    ),
              ),
    );
  }
}