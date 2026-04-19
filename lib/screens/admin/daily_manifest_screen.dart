import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد مهم لفحص بيئة الويب
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; 
import 'package:shimmer/shimmer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http; 
import 'dart:convert'; 
import 'package:shared_preferences/shared_preferences.dart'; 

import '../../services/api_service.dart';

class DailyManifestScreen extends StatefulWidget {
  const DailyManifestScreen({super.key});

  @override
  State<DailyManifestScreen> createState() => _DailyManifestScreenState();
}

class _DailyManifestScreenState extends State<DailyManifestScreen> {
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B);
  final Color bgGray = const Color(0xFFF8FAFC);

  bool _isLoading = true;
  List<dynamic> _allScheduledOrders = [];
  
  List<DateTime> _agendaDays = [];
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _generateAgendaDays();
    _fetchScheduledOrders();
  }

  void _generateAgendaDays() {
    DateTime today = DateTime.now();
    _agendaDays = List.generate(7, (index) => today.add(Duration(days: index)));
    _selectedDay = DateTime(today.year, today.month, today.day);
  }

  Future<void> _fetchScheduledOrders() async {
    setState(() => _isLoading = true);
    try {
      final pending = await ApiService.getPendingOrders();
      final approved = await ApiService.getApprovedOrders();
      
      List<dynamic> combined = [...pending, ...approved];
      
      setState(() {
        _allScheduledOrders = combined.where((o) {
          if (o['delivery_status'] == 'assigned' || o['delivery_status'] == 'picked_up') return false;
          return true;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getOrdersForSelectedDay() {
    String selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDay);
    
    return _allScheduledOrders.where((order) {
      String? dateStr;
      if (order['scheduled_date'] != null) {
        dateStr = order['scheduled_date'].toString().split('T')[0];
      } else if (order['created_at'] != null) {
        dateStr = order['created_at'].toString().split('T')[0];
      }
      return dateStr == selectedDateStr;
    }).toList();
  }

  // =========================================================================
  // 🚚 نظام إسناد الطرود للسائقين (مُحدث بخاصية تخطي الـ NFC)
  // =========================================================================

  void _showDriverSelectionDialog(int shipmentId) async {
    _showLoadingDialog("جاري جلب قائمة الأسطول...");
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

      final response = await http.get(Uri.parse('${ApiService.baseUrl}/admin/fleet'), headers: headers);
      
      if (!mounted) return;
      Navigator.pop(context); 

      if (response.statusCode == 200) {
        List<dynamic> drivers = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (drivers.isEmpty) {
          _showSnackBar("⚠️ لا يوجد سائقون مسجلون في النظام حالياً!", Colors.orange.shade800);
          return;
        }
        
        _buildDriversBottomSheet(shipmentId, drivers);
      } else {
        _showSnackBar("❌ فشل في جلب بيانات الأسطول!", Colors.red);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      _showSnackBar("❌ حدث خطأ في الاتصال بالخادم!", Colors.red);
    }
  }

  void _buildDriversBottomSheet(int shipmentId, List<dynamic> drivers) {
    bool bypassNfc = false; // 🔥 المتغير السحري لتخطي الـ NFC

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // لجعل الحواف تظهر بوضوح في الويب
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Center(
              // 🔥 تحديد عرض القائمة في الويب كي لا تتمدد كثيراً
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                  ),
                  height: MediaQuery.of(context).size.height * 0.7,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(Icons.local_shipping_rounded, color: primaryRed, size: 28),
                          const SizedBox(width: 10),
                          Text("اختر السائق لتسليمه الطرد 🚚", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // 🔥 خانة اختيار تخطي الـ NFC الإدارية
                      Container(
                        decoration: BoxDecoration(
                          color: bypassNfc ? Colors.orange.shade50 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: bypassNfc ? Colors.orange.shade300 : Colors.grey.shade200, width: 1.5)
                        ),
                        child: CheckboxListTile(
                          value: bypassNfc,
                          activeColor: Colors.orange.shade800,
                          checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          title: Text("تخطي تأكيد الاستلام (بدون NFC السائق)", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: darkBlue)),
                          subtitle: Text("سيتم تحويل الطرد مباشرة إلى حالة 'في الطريق'", style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade600)),
                          onChanged: (val) {
                            setSheetState(() {
                              bypassNfc = val ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 15),

                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: drivers.length,
                          itemBuilder: (context, index) {
                            final driver = drivers[index];
                            String driverName = driver['username'] ?? driver['driver_name'] ?? 'سائق مجهول';
                            int driverId = driver['id'];

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 10),
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                              child: ListTile(
                                leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: Icon(Icons.person, color: Colors.blue.shade700)),
                                title: Text(driverName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                subtitle: Text("ID: $driverId", style: GoogleFonts.poppins(fontSize: 11)),
                                trailing: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: darkBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                                  label: Text("إسناد", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    Navigator.pop(ctx); 
                                    // 🔥 نمرر قيمة التخطي لدالة الإسناد
                                    _assignToDriverConfirm(shipmentId, driverId, driverName, bypassNfc: bypassNfc);
                                  },
                                ),
                              ),
                            );
                          }
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _assignToDriverConfirm(int shipmentId, int driverId, String driverName, {bool bypassNfc = false}) async {
    _showLoadingDialog("جاري إسناد الطرد للسائق $driverName...");
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

      final url = Uri.parse('${ApiService.baseUrl}/admin/shipments/$shipmentId/assign');
      final response = await http.put(url, headers: headers, body: jsonEncode({'driver_id': driverId}));

      if (!mounted) return;
      Navigator.pop(context); 

      if (response.statusCode == 200) {
        
        // 🔥 إذا قام الأدمن بتفعيل خيار "تخطي NFC"، نحدث الحالة فوراً إلى picked_up
        if (bypassNfc) {
          bool statusUpdated = await ApiService.updateOrderStatus(shipmentId, 'picked_up');
          if (statusUpdated) {
            _showSnackBar("✅ تم الإسناد وتخطي الـ NFC! الطرد الآن 'في الطريق' 🚀", Colors.green.shade700);
          } else {
            _showSnackBar("⚠️ تم الإسناد ولكن حدث خطأ في تحديث الحالة.", Colors.orange.shade800);
          }
        } else {
          _showSnackBar("✅ تم الإسناد لـ $driverName بنجاح (بانتظار مسح بطاقته)!", Colors.green.shade700);
        }
        
        _fetchScheduledOrders(); 
      } else {
        _showSnackBar("❌ فشل عملية الإسناد! يرجى المحاولة لاحقاً.", Colors.red);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar("❌ حدث خطأ في الاتصال بالخادم.", Colors.red);
    }
  }

  // =========================================================================
  // 📄 نظام طباعة الـ PDF
  // =========================================================================
  Future<void> _printDailyManifest(List<dynamic> orders) async {
    if (orders.isEmpty) {
      _showSnackBar("لا توجد طرود في هذا اليوم لطباعتها!", Colors.orange.shade800);
      return;
    }

    _showLoadingDialog("جاري تحضير ملف الـ PDF...");
    
    try {
      final pdf = pw.Document();
      final arabicFont = await PdfGoogleFonts.cairoSemiBold();
      String printDate = DateFormat('yyyy-MM-dd').format(_selectedDay);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: arabicFont),
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("DANTE LOGISTICS", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                    pw.Text("بيان الشحن اليومي", style: pw.TextStyle(fontSize: 20)),
                  ]
                )
              ),
              pw.SizedBox(height: 10),
              pw.Text("تاريخ التجهيز: $printDate", style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              pw.Text("إجمالي الطرود: ${orders.length}", style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              pw.SizedBox(height: 20),
              
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 12),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 11),
                cellAlignment: pw.Alignment.center,
                headers: ['المبلغ (دج)', 'المنتجات / الكمية', 'رقم الهاتف', 'اسم الزبون', 'رقم التتبع'],
                data: orders.map((o) {
                  String itemsStr = "غير محدد";
                  if (o['items'] != null && o['items'] is List) {
                    itemsStr = (o['items'] as List).map((i) => "${i['name']} (x${i['qty']})").join(' + ');
                  }
                  
                  double oAmount = double.tryParse(o['cash_amount']?.toString() ?? '0') ?? 0.0;
                  String formattedOAmount = NumberFormat('#,##0.00').format(oAmount);

                  return [
                    formattedOAmount,
                    itemsStr,
                    o['customer_phone'] ?? '-',
                    o['customer_name'] ?? 'مجهول',
                    o['tracking_number']?.toString().substring(0, 10) ?? '-',
                  ];
                }).toList(),
              ),
              
              pw.SizedBox(height: 40),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("توقيع مسؤول المخزن: ....................", style: const pw.TextStyle(fontSize: 12)),
                  pw.Text("توقيع السائق المستلم: ....................", style: const pw.TextStyle(fontSize: 12)),
                ]
              )
            ];
          },
        ),
      );

      if (mounted) Navigator.pop(context); 
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Manifest_$printDate.pdf',
      );

    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar("حدث خطأ أثناء إنشاء الـ PDF.", Colors.red);
      debugPrint("PDF Error: $e");
    }
  }

  void _showLoadingDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Row(
          children: [
            const CircularProgressIndicator(color: Colors.purple),
            const SizedBox(width: 20),
            Expanded(child: Text(msg, style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
          ],
        ),
      )
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _formatDayName(DateTime date) {
    DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    DateTime compareDate = DateTime(date.year, date.month, date.day);
    
    if (compareDate == today) return "اليوم";
    if (compareDate == today.add(const Duration(days: 1))) return "غداً";
    
    List<String> days = ["الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الأحد"];
    return days[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb; // 🔥 فحص الويب
    List<dynamic> currentOrders = _getOrdersForSelectedDay();

    return Scaffold(
      backgroundColor: bgGray,
      appBar: AppBar(
        title: Text("تجهيز شحنات اليوم 🚛", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkBlue),
        // 🔥 إخفاء القائمة العلوية في الكمبيوتر
        leading: isDesktop ? const SizedBox.shrink() : null,
        actions: [
          IconButton(
            tooltip: "طباعة بيان الشحن (PDF)",
            icon: Icon(Icons.print_rounded, color: primaryRed, size: 28),
            onPressed: () => _printDailyManifest(currentOrders),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 0), // إعطاء مساحة تنفس في الويب
        child: Column(
          children: [
            _buildDaysSelector(),
            Expanded(
              child: _isLoading 
                ? _buildShimmer(isDesktop)
                : _buildOrdersList(currentOrders, isDesktop),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDaysSelector() {
    return Container(
      height: 80,
      color: Colors.transparent, // شفافية ليتماشى مع الويب بشكل أفضل
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _agendaDays.length,
        itemBuilder: (context, index) {
          DateTime day = _agendaDays[index];
          bool isSelected = _selectedDay.year == day.year && _selectedDay.month == day.month && _selectedDay.day == day.day;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = DateTime(day.year, day.month, day.day)),
            child: Container(
              width: 75,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.purple.shade600 : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: isSelected ? [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                border: Border.all(color: isSelected ? Colors.purple : Colors.transparent)
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_formatDayName(day), style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade600)),
                  Text(DateFormat('dd/MM').format(day), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : darkBlue)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrdersList(List<dynamic> orders, bool isDesktop) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 15),
            Text("لا توجد طرود مجدولة لهذا اليوم", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
            Text("يمكنك أخذ استراحة أو مراجعة أيام أخرى", style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return isDesktop
      // 🔥 استخدام GridView للويب لعدم تمدد البطاقات
      ? GridView.builder(
          padding: const EdgeInsets.all(15),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, 
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 2.0, // لتحديد ارتفاع البطاقة نسبة إلى عرضها
          ),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(orders[index], isDesktop);
          },
        )
      // الاستخدام العادي للهاتف
      : ListView.builder(
          padding: const EdgeInsets.all(15),
          physics: const BouncingScrollPhysics(),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(orders[index], isDesktop);
          },
        );
  }

  // 🔥 فصلنا البطاقة ليسهل التحكم بهوامشها في الويب والهاتف
  Widget _buildOrderCard(Map<String, dynamic> order, bool isDesktop) {
    bool isAwaitingCustomer = order['customer_approval_status'] == 'pending';

    final double amount = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
    final String formattedAmount = NumberFormat('#,##0.00').format(amount);

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: EdgeInsets.only(bottom: isDesktop ? 0 : 15), // إزالة الهامش إذا كان Grid
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("تتبع: ${order['tracking_number']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade600)),
                if (isAwaitingCustomer)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text("بانتظار موافقة الزبون", style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text("موعد معتمد", style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  )
              ],
            ),
            const Divider(),
            Row(
              children: [
                CircleAvatar(backgroundColor: Colors.blue.shade50, child: Icon(Icons.person, color: Colors.blue.shade700)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order['customer_name'] ?? 'زبون', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)),
                      Text(order['customer_phone'] ?? '-', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Text("$formattedAmount دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: primaryRed)),
              ],
            ),
            const SizedBox(height: 10),
            
            // قائمة المنتجات
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("المنتجات المطلوب تجهيزها:", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600)),
                      if (order['items'] != null && order['items'] is List)
                        ...(order['items'] as List).map((i) => Text("• ${i['name']} (الكمية: ${i['qty']})", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)))
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAwaitingCustomer ? Colors.grey.shade300 : darkBlue,
                  foregroundColor: isAwaitingCustomer ? Colors.grey.shade600 : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10)
                ),
                onPressed: isAwaitingCustomer ? null : () => _showDriverSelectionDialog(order['id']),
                icon: const Icon(Icons.outbox_rounded, size: 20),
                label: Text(isAwaitingCustomer ? "لا يمكن الشحن قبل موافقة الزبون" : "تجهيز وإسناد لسائق 🚚", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer(bool isDesktop) {
    return isDesktop
      ? GridView.builder(
          padding: const EdgeInsets.all(15),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 2.0),
          itemCount: 6,
          itemBuilder: (ctx, i) => Shimmer.fromColors(
            baseColor: Colors.grey.shade200, highlightColor: Colors.white,
            child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15))),
          ),
        )
      : ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: 4,
          itemBuilder: (ctx, i) => Shimmer.fromColors(
            baseColor: Colors.grey.shade200, highlightColor: Colors.white,
            child: Container(height: 180, margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15))),
          ),
        );
  }
}