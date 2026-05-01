import 'dart:convert';
import 'dart:typed_data'; // 🔥 استيراد للتعامل مع صور المصروفات
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد مهم لفحص بيئة الويب
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:badges/badges.dart' as badges;
import 'package:intl/intl.dart'; 
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart'; // 🔥 استيراد الكاميرا للمصروفات

import '../../widgets/admin/admin_drawer.dart';
import '../../services/api_service.dart';
import '../../widgets/admin/stat_card_widget.dart';
import '../../widgets/admin/fleet_radar_widget.dart';
import '../../widgets/shared/order_timeline_widget.dart';
import '../../widgets/admin/shipment_journey_timeline.dart';
import '../../widgets/admin/driver_profile_sheet.dart'; 
import '../../widgets/admin/advanced_split_dialog.dart'; 
import '../../widgets/admin/verify_payment_dialog.dart';
import '../../widgets/master_pin_dialog.dart'; // 🔥 استيراد نافذة كود المدير السري

import 'master_tracking_screen.dart'; 
import 'add_user_screen.dart'; 

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B); 
  final Color softBg = const Color(0xFFF8FAFC);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color pendingPurple = const Color(0xFF9C27B0); 
  final Color bgGray = const Color(0xFFF4F7F9); 
  
  bool _isLoading = true;
  bool _hasError = false; 
  bool _hasNewNotification = false;
  DateTime? _lastUpdated; 

  int _totalShipments = 0;
  int _pendingDeliveries = 0;
  int _pendingVerifications = 0; 
  double _moneyWithDriversAndCollectors = 0.0;
  
  // 🔥 فصل الخزينة بين الكاش والشيكات
  double _moneyInCash = 0.0;
  double _moneyInCheck = 0.0;
  
  double _totalMarketDebts = 0.0;

  List<dynamic> _fleetStatus = []; 
  List<dynamic> _allShipments = []; 
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _channel?.sink.close(); 
    super.dispose();
  }

  void _connectWebSocket() {
    try {
      String wsUrl = ApiService.baseUrl.replaceFirst('https', 'wss').replaceFirst('http', 'ws');
      _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws'));

      _channel!.stream.listen(
        (message) {
          if (message == "NEW_ORDER" || message == "STATUS_UPDATE" || message == "NEW_EXPENSE") {
            _fetchDashboardData();
            if (mounted) {
              setState(() => _hasNewNotification = true);
              _triggerSnackBar("تحديث ميداني جديد متاح 🔄");
            }
          }
        },
        onDone: () {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _connectWebSocket();
          });
        },
        onError: (error) {
          debugPrint("WebSocket Error: $error");
        },
      );
    } catch (e) { 
      debugPrint("WebSocket Initialization Error: $e"); 
    }
  }

  void _triggerSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars(); 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: darkBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(15),
        duration: const Duration(seconds: 3),
      )
    );
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return; 

      final token = prefs.getString('auth_token') ?? '';
      final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

      final results = await Future.wait([
        ApiService.getDashboardStats(),
        http.get(Uri.parse('${ApiService.baseUrl}/admin/fleet'), headers: headers).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('${ApiService.baseUrl}/admin/all-orders'), headers: headers).timeout(const Duration(seconds: 15)),
      ]);

      if (!mounted) return; 

      setState(() {
        final stats = results[0] as Map<String, dynamic>?;
        if (stats != null) {
          _totalShipments = stats['total_shipments'] ?? 0;
          _pendingDeliveries = stats['pending_deliveries'] ?? 0;
          _pendingVerifications = stats['pending_verifications'] ?? 0; 
          _moneyWithDriversAndCollectors = double.tryParse(stats['money_with_drivers']?.toString() ?? '0') ?? 0.0;
          _totalMarketDebts = double.tryParse(stats['total_market_debts']?.toString() ?? '0') ?? 0.0;
          
          // 🔥 تحديث المتغيرات الجديدة من السيرفر
          _moneyInCash = double.tryParse(stats['money_in_safe']?.toString() ?? '0') ?? 0.0; 
          _moneyInCheck = double.tryParse(stats['check_in_safe']?.toString() ?? '0') ?? 0.0;
        }

        if (results[1] is http.Response && (results[1] as http.Response).statusCode == 200) {
          _fleetStatus = jsonDecode(utf8.decode((results[1] as http.Response).bodyBytes));
        }

        List<dynamic> combined = [];
        if (results[2] is http.Response && (results[2] as http.Response).statusCode == 200) {
          List<dynamic> allOrdersFetched = jsonDecode(utf8.decode((results[2] as http.Response).bodyBytes));
          combined = allOrdersFetched.where((o) => o['delivery_status'] != 'settled').toList();
        }
        
        Map<int, dynamic> mastersMap = {};
        List<dynamic> finalTopLevelOrders = [];

        for (var o in combined) {
          if (o['master_shipment_id'] == null) {
            o['branches'] = []; 
            mastersMap[o['id']] = o;
            finalTopLevelOrders.add(o);
          }
        }

        for (var o in combined) {
          if (o['master_shipment_id'] != null) {
            int mId = o['master_shipment_id'];
            if (mastersMap.containsKey(mId)) {
              mastersMap[mId]['branches'].add(o);
            } else {
              finalTopLevelOrders.add(o);
            }
          }
        }

        finalTopLevelOrders.sort((a, b) {
          if (a['payment_status'] == 'pending_admin_verification' && b['payment_status'] != 'pending_admin_verification') return -1;
          if (b['payment_status'] == 'pending_admin_verification' && a['payment_status'] != 'pending_admin_verification') return 1;
          return (b['id'] as int).compareTo(a['id'] as int);
        });

        _allShipments = finalTopLevelOrders;
        _isLoading = false;
        _lastUpdated = DateTime.now(); 
      });
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true; 
        });
      }
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
        _triggerSnackBar("تعذر فتح واتساب. تأكد من تثبيت التطبيق.");
      }
    } catch (e) {
      _triggerSnackBar("تعذر فتح واتساب.");
    }
  }

  // 🔥 الدالة المحدثة: نافذة الحارس لحذف الطلبيات
  Future<void> _deleteOrderDialog(int id, String trackingNumber, bool isMasterHasBranches) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text("تأكيد الحذف", style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          isMasterHasBranches 
            ? "هذه طلبية أم!\nإذا قمت بحذفها، سيتم مسحها بالكامل مع جميع الدفعات المتفرعة منها نهائياً. هل أنت متأكد؟"
            : "هل أنت متأكد من حذف الدفعة ($trackingNumber)؟\n(سيتم إرجاع القطع والمبالغ للطلبية الأم تلقائياً).",
          style: GoogleFonts.cairo(fontSize: 14, height: 1.5)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx); // إغلاق نافذة التأكيد العادية
              
              // 🔥 فتح نافذة الحارس (الرمز السري)
              String? pin = await MasterPinDialog.show(context);
              
              if (pin != null && pin.isNotEmpty) {
                setState(() => _isLoading = true);
                
                // إرسال طلب الحذف للسيرفر مرفقاً بكود المدير
                final result = await ApiService.deleteShipment(id, pin);
                
                if (result['success'] == true) {
                  _triggerSnackBar("✅ ${result['message']}");
                  _fetchDashboardData();
                } else {
                  _triggerSnackBar("❌ ${result['message']}");
                  setState(() => _isLoading = false);
                }
              }
            }, 
            child: Text("نعم، احذفها", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold))
          )
        ]
      )
    );
  }

  void _showRescheduleDialog(Map<String, dynamic> order) {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    bool requireApproval = true; 

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.edit_calendar_rounded, color: Colors.orange.shade800),
                const SizedBox(width: 10),
                Text("إعادة جدولة الموعد", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                  title: Text("التاريخ: ${DateFormat('yyyy-MM-dd').format(selectedDate)}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                  trailing: const Icon(Icons.calendar_month, color: Colors.blue),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030)
                    );
                    if (picked != null) setModalState(() => selectedDate = picked);
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                  title: Text("الوقت: ${selectedTime.format(context)}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                  trailing: const Icon(Icons.access_time_filled_rounded, color: Colors.blue),
                  onTap: () async {
                    TimeOfDay? picked = await showTimePicker(context: context, initialTime: selectedTime);
                    if (picked != null) setModalState(() => selectedTime = picked);
                  },
                ),
                const SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: requireApproval ? Colors.purple.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    activeColor: Colors.purple,
                    title: Text(requireApproval ? "يتطلب موافقة الزبون" : "جدولة إجبارية (مباشرة)", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text(requireApproval ? "سوف يحتاج الزبون للتأكيد" : "جاهز للإسناد فوراً", style: GoogleFonts.cairo(fontSize: 10)),
                    value: requireApproval,
                    onChanged: (val) => setModalState(() => requireApproval = val),
                  ),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);
                  
                  DateTime finalDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                  
                  bool success = await ApiService.rescheduleOrder(order['id'], finalDateTime, requireApproval);
                  
                  if (success) {
                    _fetchDashboardData();
                    String formattedDate = DateFormat('yyyy-MM-dd').format(finalDateTime);
                    String formattedTime = DateFormat('HH:mm').format(finalDateTime);
                    
                    String whatsappMsg = requireApproval 
                      ? "مرحباً ${order['customer_name']} 👋\nلقد قمنا بتحديث موعد طلبيتك رقم (${order['tracking_number'].toString().substring(0,8)}).\n📅 الموعد: $formattedDate\n⏰ الوقت: $formattedTime\nيرجى تأكيد الموعد من التطبيق. 🚚"
                      : "مرحباً ${order['customer_name']} 👋\nتم تأكيد موعد تسليم طلبيتك رقم (${order['tracking_number'].toString().substring(0,8)}).\n📅 الموعد المؤكد: $formattedDate\n⏰ الوقت: $formattedTime\nسنكون في الموعد! 🚚";
                        
                    _triggerSnackBar("✅ تمت الجدولة بنجاح!");
                    if (order['customer_phone'] != null) {
                      await _launchWhatsApp(order['customer_phone'].toString(), whatsappMsg);
                    }
                  } else {
                    setState(() => _isLoading = false);
                    _triggerSnackBar("❌ فشل تحديث الموعد");
                  }
                },
                child: Text("حفظ", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
      ),
    );
  }

  void _showStatInfoDialog(String title, String content, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        content: Text(content, style: GoogleFonts.cairo(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text("حسناً فهمت", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue))
          )
        ],
      )
    );
  }

  // 🔥 إضافة دالة تسجيل المصروف للإدارة
  void _showAddAdminExpenseSheet() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    
    Uint8List? selectedImageBytes;
    String? base64Image;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20, right: 20, top: 20
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.money_off_rounded, color: primaryRed, size: 28),
                      const SizedBox(width: 10),
                      Text("صرف مالي من الخزينة", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text("سيتم الخصم المباشر واعتماد المصروف فوراً للمدير.", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: "المبلغ (دج)*",
                      labelStyle: GoogleFonts.cairo(),
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                      filled: true,
                      fillColor: bgGray,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    style: GoogleFonts.cairo(),
                    decoration: InputDecoration(
                      labelText: "بيان المصروف (سبب الدفع)*",
                      labelStyle: GoogleFonts.cairo(),
                      prefixIcon: const Icon(Icons.edit_document),
                      filled: true,
                      fillColor: bgGray,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),

                  InkWell(
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                      
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        setModalState(() {
                          selectedImageBytes = bytes;
                          base64Image = base64Encode(bytes);
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: selectedImageBytes == null ? Colors.orange.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selectedImageBytes == null ? Colors.orange.shade300 : Colors.green.shade300),
                      ),
                      child: Column(
                        children: [
                          Icon(selectedImageBytes == null ? Icons.camera_alt_rounded : Icons.check_circle_rounded, color: selectedImageBytes == null ? Colors.orange.shade800 : Colors.green.shade800, size: 30),
                          const SizedBox(height: 5),
                          Text(selectedImageBytes == null ? "التقط صورة البون الفاتورة (إجباري)*" : "تم إرفاق صورة البون بنجاح", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: selectedImageBytes == null ? Colors.orange.shade800 : Colors.green.shade800)),
                          if (selectedImageBytes != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(selectedImageBytes!, height: 80, width: double.infinity, fit: BoxFit.cover))
                          ]
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: isSubmitting ? null : () async {
                        final double? amount = double.tryParse(amountController.text.trim());
                        final String desc = descController.text.trim();

                        if (amount == null || amount <= 0) {
                          _triggerSnackBar("يرجى إدخال مبلغ صحيح");
                          return;
                        }
                        if (desc.isEmpty) {
                          _triggerSnackBar("يرجى كتابة بيان المصروف");
                          return;
                        }
                        if (base64Image == null) {
                          _triggerSnackBar("لا يمكن اعتماد المصروف بدون صورة البون!");
                          return;
                        }

                        setModalState(() => isSubmitting = true);

                        bool success = await ApiService.submitDriverExpense(amount, desc, receiptImage: base64Image);

                        setModalState(() => isSubmitting = false);

                        if (success) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          _triggerSnackBar("تم تسجيل المصروف وخصمه من الخزينة ✅");
                          _fetchDashboardData(); 
                        } else {
                          _triggerSnackBar("حدث خطأ أثناء الاتصال.");
                        }
                      },
                      child: isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : Text("تأكيد وخصم المصروف", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _showOrdersListSheet(String title, Color color, IconData icon, List<dynamic> ordersList) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.8, 
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 10),
                  Text(title, style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text("${ordersList.length}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: color)),
                  )
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ordersList.isEmpty
                  ? Center(child: Text("لا توجد بيانات مطابقة حالياً", style: GoogleFonts.cairo(color: Colors.grey, fontSize: 16)))
                  : ListView.builder(
                      itemCount: ordersList.length,
                      itemBuilder: (context, index) {
                        final order = ordersList[index];
                        final double amount = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
                        final String formattedAmount = NumberFormat('#,##0.00').format(amount);

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          color: Colors.grey.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.inventory_2_rounded, color: color, size: 18)),
                            title: Text(order['customer_name'] ?? 'زبون مجهول', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text("تتبع: ${order['tracking_number']?.toString() ?? '-'}", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                            trailing: Text("$formattedAmount دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                            onTap: () => _showJourneySheet(order),
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

  void _showDriversMoneySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.6, 
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.orange.shade700, size: 28),
                  const SizedBox(width: 10),
                  Text("تفاصيل العهدة لدى الأسطول", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: _fleetStatus.isEmpty
                  ? Center(child: Text("لا توجد بيانات مالية مسجلة للأسطول", style: GoogleFonts.cairo(color: Colors.grey, fontSize: 16)))
                  : ListView.builder(
                      itemCount: _fleetStatus.length,
                      itemBuilder: (context, index) {
                        final driver = _fleetStatus[index];
                        String driverName = driver['username'] ?? driver['driver_name'] ?? 'سائق';
                        
                        double collectedMoney = double.tryParse(driver['current_cash_balance']?.toString() ?? driver['collected_money']?.toString() ?? '0') ?? 0.0;
                        final String formattedCollected = NumberFormat('#,##0.00').format(collectedMoney);
                        
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          color: Colors.grey.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: Icon(Icons.person, color: Colors.orange.shade800)),
                            title: Text(driverName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                            subtitle: Text("ID: ${driver['id'] ?? '-'}", style: GoogleFonts.poppins(fontSize: 11)),
                            trailing: Text("$formattedCollected دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 16)),
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

  void _showJourneySheet(Map<String, dynamic> order) {
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

  void _showSplitDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AdvancedSplitDialog(
        order: order,
        onSuccess: (String whatsappMsg, String phone) async {
          _triggerSnackBar("✅ تم التقسيم! جاري فتح واتساب لإبلاغ الزبون...");
          _fetchDashboardData();
          if (phone.isNotEmpty) {
            await _launchWhatsApp(phone, whatsappMsg);
          }
        },
        onError: () => _triggerSnackBar("❌ حدث خطأ أثناء التقسيم!"),
      )
    );
  }

  void _showDriverMissionsQuickView(int driverId, String driverName) {
    final driverData = _fleetStatus.firstWhere((d) => d['id'] == driverId, orElse: () => null);
    
    if (driverData == null) {
      _triggerSnackBar("لم يتم العثور على بيانات هذا السائق!");
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DriverProfileSheet(driverData: driverData),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return "صباح الخير";
    if (hour >= 12 && hour < 17) return "طاب مساؤك";
    return "مساء الخير";
  }

  String _formatTime(DateTime time) {
    String h = time.hour.toString().padLeft(2, '0');
    String m = time.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  Widget _buildActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb; 

    return Scaffold(
      backgroundColor: softBg,
      appBar: _buildAppBar(isDesktop),
      drawer: isDesktop ? null : const AdminDrawer(), 
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterTrackingScreen())).then((_) => _fetchDashboardData()),
        backgroundColor: darkBlue,
        icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white),
        label: Text("الرادار", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        color: primaryRed,
        child: _isLoading ? _buildShimmerLoading(isDesktop) : _buildMainContent(isDesktop),
      ),
    );
  }

  Widget _buildMainContent(bool isDesktop) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(isDesktop ? 40 : 20, 20, isDesktop ? 40 : 20, 90), 
      children: [
        _buildWelcomeHeader(),
        const SizedBox(height: 24),
        _isLoading ? _buildShimmerLoading(isDesktop) : _buildRealStats(isDesktop),
        const SizedBox(height: 24), 
        _buildSectionHeader("رادار السائقين والمحصلين 📡", "مراقبة الأسطول والسيولة الميدانية", Icons.track_changes_rounded),
        const SizedBox(height: 16),
        _isLoading ? _buildShimmerRadar() : FleetRadarWidget(fleetStatus: _fleetStatus, onDriverTap: _showDriverMissionsQuickView),
        const SizedBox(height: 24),
        
        _buildSectionHeader(
          "آخر العمليات النشطة 📋", 
          "الطلبيات التي لم يتم تصفيتها مالياً بعد", 
          Icons.history_rounded,
          actionText: "الرادار الشامل",
          onAction: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MasterTrackingScreen())),
        ),
        
        const SizedBox(height: 16),
        _isLoading ? _buildShimmerTable() : _buildOrderGrid(),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDesktop) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: darkBlue,
      centerTitle: true,
      leading: isDesktop ? const SizedBox.shrink() : null,
      title: Text("DANTE CLOUD", style: GoogleFonts.poppins(fontWeight: FontWeight.w800, letterSpacing: 1.2, color: primaryRed)),
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          icon: Icon(Icons.print_rounded, color: darkBlue),
          tooltip: "طباعة التقرير المالي",
          onPressed: () async {
            final Uri url = Uri.parse('${ApiService.baseUrl}/admin/reports/financial-summary');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            } else {
              _triggerSnackBar("التقرير المالي غير متوفر أو قيد المعالجة.");
            }
          },
        ),
        badges.Badge(
          showBadge: _hasNewNotification,
          position: badges.BadgePosition.topEnd(top: 12, end: 12),
          badgeStyle: badges.BadgeStyle(badgeColor: Colors.amber.shade600, padding: const EdgeInsets.all(5)),
          child: IconButton(
            icon: Icon(Icons.notifications_outlined, color: darkBlue, size: 26),
            onPressed: () {
              setState(() => _hasNewNotification = false);
              _fetchDashboardData(); 
            },
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryRed, const Color(0xFF991B1B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primaryRed.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${_getGreeting()}، مدير النظام 👋", style: GoogleFonts.cairo(fontSize: 14, color: Colors.white70)),
                Text("لوحة القيادة المركزية", style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                if (_lastUpdated != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.sync_rounded, color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Text("مُحدث: ${_formatTime(_lastUpdated!)}", style: GoogleFonts.cairo(fontSize: 11, color: Colors.white70)),
                    ],
                  )
                ]
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 32),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String sub, IconData icon, {VoidCallback? onAction, String? actionText}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.blue.shade700, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
              Text(sub, style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade500, height: 1)),
            ],
          ),
        ),
        if (onAction != null && actionText != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: primaryRed, padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Text(actionText, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
          )
      ],
    );
  }

  Widget _buildRealStats(bool isDesktop) {
    final String formattedDebts = NumberFormat('#,##0.00').format(_totalMarketDebts);
    final String formattedDriversSafe = NumberFormat('#,##0.00').format(_moneyWithDriversAndCollectors);
    final String formattedCash = NumberFormat('#,##0.00').format(_moneyInCash);
    final String formattedCheck = NumberFormat('#,##0.00').format(_moneyInCheck);

    return Column(
      children: [
        if (_pendingVerifications > 0)
          InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MasterTrackingScreen()));
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange.shade700, Colors.orange.shade900]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.notification_important_rounded, color: Colors.white, size: 40),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("بانتظار مراجعتك المالية (تأكيد الدفع)", style: GoogleFonts.cairo(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text("$_pendingVerifications طلبية صرح بها الزبائن", style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.5), size: 18),
                ],
              ),
            ),
          ),
          
        StatCardWidget(
          title: "إجمالي ديون العملاء بالسوق", 
          value: "$formattedDebts دج", 
          icon: Icons.warning_amber_rounded, 
          iconColor: primaryRed, 
          isFullWidth: true,
          onTap: () => _showStatInfoDialog(
            "ديون العملاء بالسوق", 
            "هذا المبلغ ($formattedDebts دج) يمثل إجمالي قيمة الطلبيات التي تم تسليمها للزبائن بطريقة 'الدفع بالآجل' (الدين) ولم يتم تسديدها بعد.", 
            Icons.warning_amber_rounded, 
            primaryRed
          ),
        ),
        const SizedBox(height: 15),
        
        GridView.count(
          crossAxisCount: isDesktop ? 4 : 2, 
          crossAxisSpacing: 15, 
          mainAxisSpacing: 15, 
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), 
          childAspectRatio: isDesktop ? 1.5 : 1.10, 
          children: [
            StatCardWidget(
              title: "بعهدة الأسطول", 
              value: "$formattedDriversSafe دج", 
              icon: Icons.account_balance_wallet_rounded, 
              iconColor: Colors.orange.shade700,
              onTap: _showDriversMoneySheet, 
            ),
            // 🔥 تعديل بطاقة الكاش لتتضمن زر المصروفات!
            InkWell(
              onTap: () {
                _showStatInfoDialog(
                  "أموال الخزينة (النقدي)", 
                  "إجمالي الأموال النقدية (الكاش) التي تم استلامها وتصفيتها في الخزينة المركزية هو ($formattedCash دج).", 
                  Icons.payments_rounded, 
                  Colors.green.shade600
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.payments_rounded, color: Colors.green.shade600, size: 22),
                        ),
                        // 🔥 زر المصروفات الخاص بالمدير
                        InkWell(
                          onTap: _showAddAdminExpenseSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              children: [
                                Icon(Icons.money_off, size: 12, color: primaryRed),
                                const SizedBox(width: 4),
                                Text("صرف", style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: primaryRed))
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    FittedBox(fit: BoxFit.scaleDown, child: Text("$formattedCash دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: darkBlue))),
                    Text("كاش الخزينة 💵", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            StatCardWidget(
              title: "شيكات الخزينة 📄", 
              value: "$formattedCheck دج", 
              icon: Icons.receipt_long_rounded, 
              iconColor: Colors.purple.shade600,
              onTap: () => _showStatInfoDialog(
                "أموال الخزينة (الشيكات)", 
                "إجمالي قيمة الشيكات البنكية أو البريدية التي تم تصفيتها في الخزينة المركزية هو ($formattedCheck دج).", 
                Icons.receipt_long_rounded, 
                Colors.purple.shade600
              ),
            ),
            StatCardWidget(
              title: "قيد التوصيل", 
              value: "$_pendingDeliveries طرد", 
              icon: Icons.local_shipping_rounded, 
              iconColor: Colors.blue.shade600,
              onTap: () => _showOrdersListSheet(
                "الطلبيات قيد التوصيل", 
                Colors.blue.shade600, 
                Icons.local_shipping_rounded, 
                _allShipments.where((o) => ['picked_up', 'assigned'].contains(o['delivery_status'])).toList()
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderGrid() {
    if (_allShipments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: cardBorder)),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 50, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text("لا توجد عمليات حالية للاستعراض", style: GoogleFonts.cairo(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allShipments.length > 6 ? 6 : _allShipments.length, 
      itemBuilder: (context, index) {
        final order = _allShipments[index];
        final bool isPending = order['delivery_status'] == 'pending'; 
        final String currentStatus = order['delivery_status']?.toString() ?? 'pending';
        final String approvalStatus = order['customer_approval_status']?.toString() ?? 'not_required';
        final String paymentStatus = order['payment_status']?.toString() ?? 'unpaid';
        
        final double amount = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
        final String formattedAmount = NumberFormat('#,##0.00').format(amount);

        final List<dynamic> branches = order['branches'] ?? [];
        final bool isStandaloneBranch = order['master_shipment_id'] != null;
        
        final bool needsPaymentVerification = (paymentStatus == 'pending_admin_verification');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: needsPaymentVerification ? Colors.orange.shade400 : cardBorder, width: needsPaymentVerification ? 2 : 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showJourneySheet(order),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isStandaloneBranch ? Colors.orange.shade50 : Colors.grey.shade50, 
                            borderRadius: BorderRadius.circular(12)
                          ),
                          child: Icon(isStandaloneBranch ? Icons.call_split_rounded : Icons.receipt_long_rounded, color: isStandaloneBranch ? Colors.orange.shade800 : darkBlue, size: 22)
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(order['customer_name'] ?? 'مجهول', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: darkBlue), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  Text("$formattedAmount دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 14)),
                                ],
                              ),
                              Text("ID: ${order['tracking_number'] ?? '...'}", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _buildStatusBadge(currentStatus, approvalStatus, paymentStatus), 
                                  
                                  if (isPending) 
                                    _buildActionBtn(Icons.account_tree_rounded, pendingPurple, () => _showSplitDialog(order)),
                                  if (['pending', 'pending_approval', 'approved'].contains(currentStatus.toLowerCase()))
                                    _buildActionBtn(Icons.edit_calendar_rounded, Colors.orange.shade800, () => _showRescheduleDialog(order)),
                                    
                                  if (needsPaymentVerification)
                                    InkWell(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => VerifyPaymentDialog(
                                            order: order,
                                            onSuccess: () {
                                              _triggerSnackBar("✅ تم تأكيد الدفع وإغلاق الطلبية نهائياً!");
                                              _fetchDashboardData();
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
                                    
                                  _buildActionBtn(Icons.history_edu_rounded, Colors.blue.shade700, () => _showJourneySheet(order)),
                                  _buildActionBtn(Icons.delete_outline_rounded, Colors.red, () => _deleteOrderDialog(order['id'], order['tracking_number'] ?? 'مجهول', branches.isNotEmpty)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50.withOpacity(0.3),
                      border: Border(top: BorderSide(color: Colors.grey.shade100))
                    ),
                    child: OrderTimelineWidget(
                      currentStatus: currentStatus,
                      approvalStatus: approvalStatus,
                    ),
                  ),

                  if (branches.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: pendingPurple.withOpacity(0.03),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        border: Border(top: BorderSide(color: pendingPurple.withOpacity(0.15)))
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          leading: Icon(Icons.account_tree_rounded, color: pendingPurple, size: 20),
                          title: Text("الطلبية مجزأة إلى (${branches.length}) دفعات", style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: pendingPurple)),
                          children: branches.map((b) {
                            final double bAmount = double.tryParse(b['cash_amount']?.toString() ?? '0') ?? 0.0;
                            final String bFormattedAmount = NumberFormat('#,##0.00').format(bAmount);
                            final String bStatus = b['delivery_status']?.toString() ?? 'pending';
                            final String bPaymentStatus = b['payment_status']?.toString() ?? 'unpaid';
                            final bool bNeedsPaymentVerification = (bPaymentStatus == 'pending_admin_verification');
                            
                            return Container(
                              decoration: BoxDecoration(border: Border(top: BorderSide(color: pendingPurple.withOpacity(0.1)))),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: InkWell(
                                  onTap: () => _showJourneySheet(b),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.subdirectory_arrow_left_rounded, color: Colors.grey.shade400, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(child: Text("${b['tracking_number']}", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: darkBlue), overflow: TextOverflow.ellipsis)),
                                                Text("$bFormattedAmount دج", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                _buildStatusBadge(bStatus, b['customer_approval_status']?.toString() ?? 'not_required', bPaymentStatus),
                                                
                                                if (['pending', 'pending_approval', 'approved'].contains(bStatus.toLowerCase()))
                                                  _buildActionBtn(Icons.edit_calendar_rounded, Colors.orange.shade800, () => _showRescheduleDialog(b)),
                                                  
                                                if (bNeedsPaymentVerification)
                                                  InkWell(
                                                    onTap: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (ctx) => VerifyPaymentDialog(
                                                          order: b,
                                                          onSuccess: () {
                                                            _triggerSnackBar("✅ تم تأكيد الدفع للدفعة الفرعية!");
                                                            _fetchDashboardData();
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
                                                
                                                _buildActionBtn(Icons.history_edu_rounded, Colors.blue.shade700, () => _showJourneySheet(b)),
                                                _buildActionBtn(Icons.delete_outline_rounded, Colors.red, () => _deleteOrderDialog(b['id'], b['tracking_number'] ?? 'مجهول', false)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 6)
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status, String approvalStatus, String paymentStatus) {
    Color bgColor; Color textColor; String label;
    
    if (status == 'pending_approval' && approvalStatus == 'pending') {
      bgColor = pendingPurple.withOpacity(0.1); textColor = pendingPurple; label = 'موافقة الزبون';
    } else if (status == 'delivered' && paymentStatus == 'awaiting_customer_payment') {
      bgColor = Colors.red.shade50; textColor = Colors.red.shade700; label = 'ينتظر دفع الزبون';
    } else if (paymentStatus == 'pending_admin_verification') {
      bgColor = Colors.orange.shade50; textColor = Colors.orange.shade800; label = 'تأكيد الإدارة';
    } else {
      switch (status.toLowerCase()) {
        case 'pending': bgColor = Colors.blueGrey.shade50; textColor = Colors.blueGrey.shade700; label = 'مراجعة'; break;
        case 'approved': bgColor = Colors.blue.shade50; textColor = Colors.blue.shade700; label = 'معتمد'; break;
        case 'assigned': bgColor = Colors.orange.shade50; textColor = Colors.orange.shade800; label = 'تجهيز'; break;
        case 'picked_up': 
        case 'in_transit': bgColor = Colors.orange.shade100; textColor = Colors.orange.shade900; label = 'في الطريق'; break;
        case 'delivered': bgColor = Colors.indigo.shade50; textColor = Colors.indigo.shade700; label = 'بعهدة السائق 💵'; break;
        case 'delivered_unpaid': bgColor = Colors.red.shade50; textColor = Colors.red.shade700; label = 'بالآجل'; break;
        case 'assigned_to_collector': bgColor = Colors.purple.shade50; textColor = Colors.purple.shade700; label = 'للتحصيل'; break;
        case 'settled_with_collector': bgColor = Colors.indigo.shade50; textColor = Colors.indigo.shade700; label = 'عهدة'; break;
        case 'settled': bgColor = Colors.teal.shade50; textColor = Colors.teal.shade800; label = 'مغلقة'; break;
        default: bgColor = Colors.red.shade50; textColor = Colors.red.shade700; label = status;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: textColor, height: 1)),
    );
  }

  Widget _buildShimmerLoading(bool isDesktop) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200, highlightColor: Colors.white,
      child: Column(
        children: [
          Container(height: 110, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
          const SizedBox(height: 15),
          GridView.count(
            crossAxisCount: isDesktop ? 4 : 2, crossAxisSpacing: 15, mainAxisSpacing: 15, shrinkWrap: true,
            childAspectRatio: isDesktop ? 1.5 : 1.15, children: List.generate(4, (i) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))),
          )
        ],
      ),
    );
  }

  Widget _buildShimmerRadar() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200, highlightColor: Colors.white,
      child: SizedBox(height: 140, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 3, itemBuilder: (c, i) => Container(width: 140, margin: const EdgeInsets.only(right: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15))))),
    );
  }

  Widget _buildShimmerTable() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200, highlightColor: Colors.white,
      child: Column(children: List.generate(3, (i) => Container(height: 75, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))))),
    );
  }
}