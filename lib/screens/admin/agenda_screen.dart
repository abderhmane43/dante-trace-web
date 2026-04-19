import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد مهم للويب
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../services/api_service.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  // 🎨 الألوان الاحترافية
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B);
  final Color successGreen = const Color(0xFF2E7D32);
  final Color pendingPurple = const Color(0xFF9C27B0);
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  List<dynamic> _allOrders = [];
  List<dynamic> _availableDrivers = [];
  Map<DateTime, List<dynamic>> _ordersByDay = {};
  bool _isLoading = true;

  // 🔥 متغير للتحكم في العرض (طلبيات جديدة مقابل منجزة)
  bool _showFinishedOrders = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchData();
  }

  // 📡 جلب الطلبيات المجدولة والسائقين
  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final headers = {'Authorization': 'Bearer $token'};

      final results = await Future.wait([
        http.get(Uri.parse('${ApiService.baseUrl}/admin/all-orders'), headers: headers),
        http.get(Uri.parse('${ApiService.baseUrl}/users/'), headers: headers),
      ]);

      if (results[0].statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(results[0].bodyBytes));
        
        // 🔥 الفلترة: جلب كل الطلبيات المجدولة لمعالجتها لاحقاً حسب التبويب
        _allOrders = data.where((o) => o['scheduled_date'] != null).toList();
        
        _updateCalendarEvents();
      }

      if (results[1].statusCode == 200) {
        final users = jsonDecode(utf8.decode(results[1].bodyBytes));
        _availableDrivers = users.where((u) => u['role'] == 'driver').toList();
      }

    } catch (e) {
      debugPrint("Agenda Load Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔥 دالة لتحديث الأحداث في التقويم بناءً على التبويب المختار
  void _updateCalendarEvents() {
    _ordersByDay = {};
    for (var order in _allOrders) {
      String status = order['delivery_status'] ?? '';
      bool isSettled = (status == 'settled');

      if (_showFinishedOrders) {
        if (!isSettled) continue; 
      } else {
        if (!['pending', 'pending_approval', 'approved'].contains(status)) continue;
      }

      DateTime date = DateTime.parse(order['scheduled_date']).toLocal();
      DateTime dayOnly = DateTime(date.year, date.month, date.day);
      if (_ordersByDay[dayOnly] == null) _ordersByDay[dayOnly] = [];
      _ordersByDay[dayOnly]!.add(order);
    }
  }

  // 🔍 جلب طلبيات يوم معين
  List<dynamic> _getOrdersForDay(DateTime day) {
    DateTime dayOnly = DateTime(day.year, day.month, day.day);
    return _ordersByDay[dayOnly] ?? [];
  }

  // 💬 دالة فتح الواتساب
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

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  // 🖨️ دالة طباعة أمر تجهيز المخزن (طلبية واحدة)
  Future<void> _printPickingList(int orderId) async {
    final Uri url = Uri.parse('${ApiService.baseUrl}/admin/orders/$orderId/picking-list');
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

  // 🖨️ 🔥 دالة طباعة البيان الشامل لليوم (كل الطلبيات)
  Future<void> _printDailyManifest() async {
    if (_selectedDay == null) return;
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    String type = _showFinishedOrders ? "settled" : "pending";
    
    final Uri url = Uri.parse('${ApiService.baseUrl}/admin/reports/daily-manifest?date=$dateStr&type=$type');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar("تعذر فتح ملف الطباعة", Colors.red);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء تحميل البيان", Colors.red);
    }
  }

  // =========================================================================
  // 🚚 الإسناد المباشر للسائق من التقويم مع إرسال الواتساب
  // =========================================================================
  void _showAssignBottomSheet(int shipmentId, String customerName) {
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
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, color: primaryRed, size: 28),
                    const SizedBox(width: 10),
                    Expanded(child: Text("تجهيز وإرسال الطلبية", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue))),
                  ],
                ),
                const SizedBox(height: 10),
                Text("اختر السائق الذي سيتولى توصيل طلبية الزبون: $customerName", style: GoogleFonts.cairo(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 15),

                // 🔥 خانة التخطي الذكية (Bypass)
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
                    return DropdownMenuItem(value: d['id'], child: Text("${d['username']} ${d['first_name'] != null ? '(${d['first_name']})' : ''}", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)));
                  }).toList(),
                  onChanged: (val) => setModalState(() => selectedDriverId = val),
                ),
                
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: successGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
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
                        
                        // 🔥 جلب بيانات السائق وإرسال رسالة واتساب
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
                        
                        _showSnackBar(bypassNfc ? "تم الإسناد وتخطي الـ NFC بنجاح 🚀" : "تم إرسال أمر التحاق للسائق 🚚", Colors.green.shade700);
                        
                        _fetchData(); 
                      } else {
                        if (Navigator.canPop(ctx)) Navigator.pop(ctx); 
                        _showSnackBar("حدث خطأ أثناء إسناد الطلبية", Colors.red.shade800);
                        setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    // 🔥 فحص هل التطبيق يعمل على الويب (الحاسوب)
    final isDesktop = kIsWeb; 

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("أجندة التجهيز الميداني 📅", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: darkBlue,
        elevation: 0,
        // 🔥 إخفاء القائمة العلوية (Drawer icon) في المتصفح لأن القائمة الجانبية ظاهرة دائماً
        leading: isDesktop ? const SizedBox.shrink() : null,
        actions: [
          IconButton(
            onPressed: _fetchData,
            icon: Icon(Icons.sync_rounded, color: darkBlue),
            tooltip: "تحديث الأجندة",
          )
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryRed))
        : Padding(
            // 🔥 إضافة حواف (Padding) في متصفح الحاسوب لكي لا تظهر العناصر ممتدة بشكل مبالغ فيه
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 0),
            // 🔥 تم استخدام CustomScrollView لتفعيل التمرير الكامل للصفحة
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // 🔥 تبويبات الفلترة المضافة (Filter Tabs)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(15)),
                          child: Row(
                            children: [
                              _buildFilterTab("طلبيات للتجهيز", !_showFinishedOrders, Icons.pending_actions_rounded),
                              _buildFilterTab("العمليات المنجزة", _showFinishedOrders, Icons.task_alt_rounded),
                            ],
                          ),
                        ),
                      ),

                      // 📅 كائن التقويم المتطور
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                        ),
                        child: TableCalendar(
                          locale: 'ar', 
                          firstDay: DateTime.utc(2025, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat,
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onFormatChanged: (format) => setState(() => _calendarFormat = format),
                          eventLoader: _getOrdersForDay, 
                          calendarStyle: CalendarStyle(
                            todayDecoration: BoxDecoration(color: primaryRed.withOpacity(0.2), shape: BoxShape.circle),
                            todayTextStyle: TextStyle(color: primaryRed, fontWeight: FontWeight.bold),
                            selectedDecoration: BoxDecoration(color: _showFinishedOrders ? successGreen : primaryRed, shape: BoxShape.circle),
                            markerDecoration: BoxDecoration(color: _showFinishedOrders ? successGreen : darkBlue, shape: BoxShape.circle), 
                          ),
                          headerStyle: HeaderStyle(
                            formatButtonVisible: true,
                            titleCentered: true,
                            formatButtonDecoration: BoxDecoration(color: darkBlue, borderRadius: BorderRadius.circular(12)),
                            formatButtonTextStyle: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 15),

                      // 🔥 زر الطباعة الشامل المضاف
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_showFinishedOrders ? "العمليات المكتملة:" : "طلبيات قيد الانتظار:", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 13)),
                            if (_getOrdersForDay(_selectedDay!).isNotEmpty)
                              TextButton.icon(
                                onPressed: _printDailyManifest,
                                style: TextButton.styleFrom(backgroundColor: darkBlue.withOpacity(0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                icon: Icon(Icons.picture_as_pdf_rounded, size: 18, color: darkBlue),
                                label: Text("طباعة بيان اليوم 🖨️", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: darkBlue)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                  ),
                ),
                
                // 📋 قائمة طلبيات اليوم المختار
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 30),
                  sliver: _buildDayOrdersList(),
                ),
              ],
            ),
          ),
    );
  }

  // 🔥 أداة بناء تبويب الفلترة
  Widget _buildFilterTab(String title, bool isActive, IconData icon) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showFinishedOrders = (title == "العمليات المنجزة");
            _updateCalendarEvents();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? (title == "العمليات المنجزة" ? successGreen : primaryRed) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? Colors.white : Colors.grey),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayOrdersList() {
    final orders = _getOrdersForDay(_selectedDay!);
    
    if (orders.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              Icon(Icons.event_available_rounded, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 10),
              Text(_showFinishedOrders ? "لا توجد عمليات منجزة في هذا اليوم" : "لا توجد طلبيات لتجهيزها في هذا اليوم", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
              Text("جميع الطلبيات تم إرسالها أو لا توجد مواعيد.", style: GoogleFonts.cairo(color: Colors.grey.shade400, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final order = orders[index];
          
          final double amount = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
          final String formattedAmount = NumberFormat('#,##0.00').format(amount);
          final DateTime scheduledTime = DateTime.parse(order['scheduled_date']).toLocal();
          final String timeStr = DateFormat('HH:mm').format(scheduledTime);
          
          List<dynamic> itemsList = [];
          if (order['items'] is String) {
            try { itemsList = jsonDecode(order['items']); } catch(e) { itemsList = []; }
          } else if (order['items'] is List) {
            itemsList = order['items'];
          }

          bool isPendingApproval = order['customer_approval_status'] == 'pending';

          return Container(
            margin: const EdgeInsets.only(bottom: 15, left: 16, right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _showFinishedOrders ? successGreen.withOpacity(0.5) : (isPendingApproval ? pendingPurple.withOpacity(0.5) : Colors.grey.shade300)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    color: _showFinishedOrders ? successGreen : (isPendingApproval ? pendingPurple : darkBlue),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15))
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 5),
                          Text("موعد الاستلام: $timeStr", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Text("#${order['tracking_number']?.toString().substring(0,8) ?? ''}", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _showFinishedOrders ? successGreen.withOpacity(0.1) : Colors.blue.shade50, 
                            child: Icon(_showFinishedOrders ? Icons.verified_rounded : Icons.storefront_rounded, color: _showFinishedOrders ? successGreen : darkBlue)
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(order['customer_name'] ?? 'مجهول', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)),
                                Text(order['customer_address'] ?? 'بدون عنوان', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          if (isPendingApproval && !_showFinishedOrders)
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                               decoration: BoxDecoration(color: pendingPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                               child: Text("بانتظار الزبون", style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: pendingPurple)),
                             )
                        ],
                      ),
                      
                      const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                      
                      Text("تفاصيل الطلبية:", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      ...itemsList.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("• ", style: TextStyle(color: _showFinishedOrders ? successGreen : primaryRed, fontWeight: FontWeight.bold)),
                              Expanded(child: Text("${item['name']}", style: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 13))),
                              Text("x${item['qty']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: darkBlue)),
                            ],
                          ),
                        );
                      }),
                      
                      const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_showFinishedOrders ? "المبلغ المدفوع:" : "المبلغ المطلوب:", style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade600)),
                              Text("$formattedAmount دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 16)),
                            ],
                          ),
                          _showFinishedOrders 
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: successGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: successGreen, size: 16),
                                    const SizedBox(width: 4),
                                    Text("مكتملة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: successGreen, fontSize: 12)),
                                  ],
                                ),
                              )
                            : Row(
                                children: [
                                  // 🔥 زر الطباعة الفردي
                                  IconButton(
                                    onPressed: () => _printPickingList(order['id']), 
                                    icon: const Icon(Icons.print_rounded, color: Colors.blueGrey),
                                    tooltip: "طباعة للمخزن",
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isPendingApproval ? Colors.grey.shade400 : primaryRed,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    onPressed: isPendingApproval 
                                        ? null 
                                        : () => _showAssignBottomSheet(order['id'], order['customer_name']),
                                    icon: const Icon(Icons.outbox_rounded, size: 18),
                                    label: Text("إسناد 🚚", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ],
                              )
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          );
        },
        childCount: orders.length,
      ),
    );
  }
}