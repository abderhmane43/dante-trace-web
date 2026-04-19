import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/pdf_invoice_service.dart';

class DriverTasksScreen extends StatefulWidget {
  const DriverTasksScreen({super.key});

  @override
  State<DriverTasksScreen> createState() => _DriverTasksScreenState();
}

class _DriverTasksScreenState extends State<DriverTasksScreen> {
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B);
  
  bool _isLoading = true;
  List<dynamic> _myTasks = [];

  @override
  void initState() {
    super.initState();
    _fetchMyTasks();
  }

  // 📡 جلب مهام السائق من السيرفر
  Future<void> _fetchMyTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await ApiService.getDriverAssignedTasks();
      if (mounted) {
        setState(() {
          _myTasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("حدث خطأ أثناء جلب المهام. تحقق من الاتصال.", Colors.red.shade800);
      }
    }
  }

  // 🆘 زر الطوارئ: التسليم اليدوي (يستخدم فقط إذا كان هاتف الزبون معطلاً أو لا يدعم NFC)
  Future<void> _markAsDeliveredManual(int shipmentId, String customerName) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            Text("تسليم يدوي للطوارئ", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text("يفضل دائماً أن يقوم الزبون بمسح بطاقتك لتأكيد الاستلام.\nهل أنت متأكد أنك سلمت الطلب لـ ($customerName) واستلمت المبلغ وتريد التأكيد يدوياً؟", style: GoogleFonts.cairo(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("تراجع", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("نعم، استلمت المبلغ", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      bool success = await ApiService.updateOrderStatus(shipmentId, 'delivered');
      if (success) {
        _showSnackBar("تم تأكيد التسليم وإضافة المبلغ لعهدتك! ✅", Colors.green.shade700);
        _fetchMyTasks(); 
      } else {
        setState(() => _isLoading = false);
        _showSnackBar("فشل في تحديث حالة الطلبية", Colors.red.shade800);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("خطأ في الاتصال بالخادم", Colors.red.shade800);
    }
  }

  // 🖨️ دالة جلب وطباعة الفاتورة 
  Future<void> _printOrderInvoice(int shipmentId) async {
    setState(() => _isLoading = true); 
    try {
      final invoiceData = await ApiService.getInvoiceData(shipmentId);
      if (invoiceData != null) {
        await PdfInvoiceService.generateAndPrintInvoice(invoiceData);
      } else {
        _showSnackBar("فشل في جلب بيانات الإيصال", Colors.red.shade800);
      }
    } catch (e) {
      debugPrint("Print Error: $e");
      _showSnackBar("حدث خطأ أثناء معالجة الطباعة", Colors.red.shade800);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🗺️ فتح خرائط جوجل للوصول للزبون
  Future<void> _openGoogleMaps(double? lat, double? lng, String address) async {
    if (lat != null && lng != null) {
      final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        final Uri webUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
        await launchUrl(webUrl);
      }
    } else {
      _showSnackBar("الإحداثيات غير متوفرة لهذه الطلبية، العنوان: $address", Colors.orange.shade800);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("المهام والتسليم الميداني", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkBlue),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: primaryRed),
            onPressed: _fetchMyTasks,
            tooltip: "تحديث القائمة",
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryRed))
          : _myTasks.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchMyTasks,
                  color: primaryRed,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(15),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _myTasks.length,
                    itemBuilder: (context, index) {
                      return _buildTaskCard(_myTasks[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green.shade400),
          const SizedBox(height: 15),
          Text("لا توجد مهام حالياً", style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: darkBlue)),
          Text("لقد قمت بتوصيل جميع طرودك بنجاح!", style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final bool isJustAssigned = task['delivery_status'] == 'assigned';
    final Color statusColor = isJustAssigned ? Colors.orange.shade700 : Colors.green.shade700;
    final String statusText = isJustAssigned ? "تنتظر التحميل من المخزن" : "في شاحنتي (مستعد للتسليم)";
    final IconData statusIcon = isJustAssigned ? Icons.inventory_rounded : Icons.local_shipping_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isJustAssigned ? Colors.orange.shade200 : Colors.green.shade200, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: isJustAssigned ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14.5))
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(statusText, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor))),
                Text(task['tracking_number'].toString().split('-').last, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task['customer_name'] ?? 'زبون', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(child: Text("${task['customer_wilaya'] ?? ''} - ${task['customer_address'] ?? ''}", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text("${task['cash_amount']} دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryRed, fontSize: 16)),
                    )
                  ],
                ),
                const Divider(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.phone_rounded, size: 18),
                        label: Text("اتصال", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        onPressed: () async {
                          final Uri launchUri = Uri(scheme: 'tel', path: task['customer_phone']);
                          if (await canLaunchUrl(launchUri)) {
                            await launchUrl(launchUri);
                          } else {
                            _showSnackBar("لا يمكن فتح تطبيق الاتصال", Colors.red);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.directions_rounded, size: 18),
                        label: Text("توجيه GPS", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        onPressed: () => _openGoogleMaps(task['gps_latitude'], task['gps_longitude'], task['customer_address']),
                      ),
                    ),
                  ],
                ),
                
                // 🎛️ التعليمات والإجراءات النهائية
                if (!isJustAssigned) ...[
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade100)
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.nfc_rounded, color: Colors.blue.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text("المصافحة 2: اطلب من الزبون فتح تطبيقه ومسح بطاقتك لتأكيد التسليم.", style: GoogleFonts.cairo(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // زر الطوارئ اليدوي
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.touch_app_rounded, size: 16),
                          label: Text("تسليم يدوي (طوارئ)", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                          ),
                          onPressed: () => _markAsDeliveredManual(task['id'], task['customer_name']),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 🖨️ زر طباعة الفاتورة 
                      Expanded(
                        flex: 1,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.print_rounded, size: 16),
                          label: Text("طباعة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                          ),
                          onPressed: () => _printOrderInvoice(task['id']),
                        ),
                      ),
                    ],
                  )
                ]
              ],
            ),
          )
        ],
      ),
    );
  }
}