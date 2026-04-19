import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد بيئة الويب
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart'; 
import 'package:shimmer/shimmer.dart'; 
import 'package:google_fonts/google_fonts.dart'; 
import 'package:badges/badges.dart' as badges; 
import 'package:nfc_manager/nfc_manager.dart'; 
import 'package:intl/intl.dart' hide TextDirection; 
import 'package:url_launcher/url_launcher.dart'; 

import '../../services/api_service.dart';
import '../shared/login_screen.dart';
import '../../widgets/customer/checkout_dialog.dart';
import '../../widgets/customer/product_catalog_card.dart';
import '../../widgets/shared/order_timeline_widget.dart';
import 'customer_delivery_confirm_screen.dart'; 

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() => _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  // 🎨 الهوية البصرية
  final Color primaryBlue = const Color(0xFF1976D2);
  final Color successGreen = const Color(0xFF2E7D32);
  final Color warningOrange = const Color(0xFFEF6C00);
  final Color bgGray = const Color(0xFFF4F7F9);
  final Color darkBlue = const Color(0xFF0D47A1);
  final Color pendingPurple = const Color(0xFF9C27B0); 
  
  bool _isLoadingOrders = false;
  bool _isLoadingProducts = true; 
  bool _isProcessingCheckout = false; 

  List<dynamic> _activeOrders = [];
  List<dynamic> _historyOrders = [];
  List<dynamic> _products = []; 
  
  final Map<int, int> _quantities = {}; 
  final List<Map<String, dynamic>> _cart = []; 

  String _currentUsername = "زبون";
  WebSocketChannel? _channel;

  int _totalOrders = 0;
  int _inTransitOrders = 0;
  int _deliveredOrders = 0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadUserData();
    _loadProductsData(); 
    _loadCustomerData(); 
    _connectWebSocket(); 
  }

  @override
  void dispose() {
    _channel?.sink.close(); 
    super.dispose();
  }

  // 📡 محرك البث الحي
  void _connectWebSocket() {
    try {
      final wsUrl = ApiService.baseUrl.replaceFirst('https', 'wss').replaceFirst('http', 'ws') + "/ws";
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen((message) {
        if (message == "STATUS_UPDATE" || message.contains("ASSIGNED")) {
          _loadCustomerData(showLoader: false); 
          _showToast('🚚 تحديث جديد لحالة طردك!', warningOrange);
        }
      }, onDone: () {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _connectWebSocket();
        });
      });
    } catch (e) { debugPrint("WS Error: $e"); }
  }

  // 📥 جلب بيانات الطلبات (المضادة للأخطاء)
  Future<void> _loadCustomerData({bool showLoader = true}) async {
    if (showLoader) setState(() => _isLoadingOrders = true);
    try {
      final fetchedOrders = await ApiService.getCustomerHistory();

      int inTransit = 0, delivered = 0;
      List<dynamic> active = [], history = [];

      for (var order in fetchedOrders) {
        final String status = order['delivery_status'] ?? 'pending';
        final String paymentStatus = order['payment_status'] ?? 'unpaid';
        final String approvalStatus = order['customer_approval_status'] ?? 'not_required';
        final String? scheduledDateRaw = order['scheduled_date'];

        if (status == 'picked_up' || status == 'in_transit') inTransit++;
        if (status == 'settled' || paymentStatus == 'settled_with_company') delivered++;

        String formattedDate = "غير محدد";
        if (scheduledDateRaw != null) {
          DateTime dt = DateTime.parse(scheduledDateRaw);
          formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(dt);
        }

        final double orderAmount = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
        final String formattedAmount = NumberFormat('#,##0.00').format(orderAmount);

        String? driverNameStr = (order['driver_name'] != null && order['driver_name'].toString().isNotEmpty) ? order['driver_name'].toString() : null;
        String? driverPhoneStr = (order['driver_phone'] != null && order['driver_phone'].toString().isNotEmpty) ? order['driver_phone'].toString() : null;

        final formatted = {
          "id": order['id'],
          "tracking_number": order['tracking_number'],
          "status": status, 
          "payment_status": paymentStatus, 
          "approval_status": approvalStatus, 
          "scheduled_date": formattedDate, 
          "raw_amount": orderAmount, 
          "amount": "$formattedAmount دج",
          "address": order['customer_address'],
          "time": order['preferred_delivery_time'] ?? "أي وقت",
          "items": order['items'], 
          "driver_name": driverNameStr, 
          "driver_phone": driverPhoneStr, 
        };

        if (status == 'settled' || paymentStatus == 'settled_with_company') {
          history.add(formatted);
        } else {
          active.add(formatted);
        }
      }

      if (mounted) {
        setState(() {
          _activeOrders = active; 
          _historyOrders = history;
          _totalOrders = fetchedOrders.length; 
          _inTransitOrders = inTransit; 
          _deliveredOrders = delivered;
        });
      }
    } catch (e) {
      debugPrint("🚨 Error loading customer data: $e");
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  // 🛍️ جلب المنتجات
  Future<void> _loadProductsData() async {
    setState(() => _isLoadingProducts = true);
    try {
      final fetchedProducts = await ApiService.getDynamicProducts();
      if (mounted) {
        setState(() {
          _products = fetchedProducts;
          for (var p in _products) _quantities[p['id']] = 1; 
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _currentUsername = prefs.getString('username') ?? "زبون");
  }

  // 📞 الاتصال الهاتفي بالسائق
  Future<void> _callDriver(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final Uri callUrl = Uri.parse("tel:$cleanPhone");
    try {
      if (await canLaunchUrl(callUrl)) {
        await launchUrl(callUrl);
      } else {
        _showToast("لا يمكن فتح تطبيق الاتصال", Colors.red);
      }
    } catch (e) {
      _showToast("حدث خطأ أثناء الاتصال", Colors.red);
    }
  }

  // ==========================================================
  // 📄 تنزيل وصل الاستلام
  // ==========================================================
  Future<void> _downloadReceipt(int orderId) async {
    final Uri url = Uri.parse('${ApiService.baseUrl}/customer/orders/$orderId/receipt');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showToast("عذراً، الوصل غير متوفر حالياً", Colors.red);
      }
    } catch (e) {
      _showToast("حدث خطأ أثناء محاولة فتح الوصل", Colors.red);
    }
  }

  // ==========================================================
  // 📅 موافقة الزبون على الموعد المقترح
  // ==========================================================
  void _handleCustomerApproval(Map<String, dynamic> item, bool isApprove) {
    if (isApprove) {
      _submitApproval(item['id'], "approved", null);
    } else {
      TextEditingController reasonCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("تأجيل الموعد", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: reasonCtrl,
            decoration: InputDecoration(
              hintText: "اذكر السبب أو اقترح موعداً آخر...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                _submitApproval(item['id'], "rejected", reasonCtrl.text.trim());
              },
              child: Text("تأكيد التأجيل", style: GoogleFonts.cairo(color: Colors.white)),
            )
          ],
        ),
      );
    }
  }

  Future<void> _submitApproval(int shipmentId, String status, String? reason) async {
    _showLoadingOverlay();
    bool success = await ApiService.customerApproveSchedule(shipmentId, status, rejectionReason: reason);
    if (mounted && Navigator.canPop(context)) Navigator.pop(context); 

    if (success) {
      _showToast(status == "approved" ? "✅ تم تأكيد الموعد بنجاح" : "ℹ️ تم إرسال طلب التأجيل للإدارة", status == "approved" ? successGreen : warningOrange);
      _loadCustomerData(); 
    } else {
      _showToast("❌ حدث خطأ، يرجى المحاولة لاحقاً", Colors.red);
    }
  }

  // ==========================================================
  // 💸 نافذة التصريح بالدفع الجديدة (Customer Payment Declaration)
  // ==========================================================
  void _showPaymentDeclarationSheet(Map<String, dynamic> item) {
    final double totalRequired = item['raw_amount'];
    
    // متغيرات الحالة داخل النافذة
    double cashAmount = totalRequired; // الافتراضي أن يدفع كاش بالكامل
    double chequeAmount = 0.0;
    double debtAmount = 0.0;
    String chequeRef = "";

    // للتحكم في حقول الإدخال
    TextEditingController cashCtrl = TextEditingController(text: cashAmount.toStringAsFixed(0));
    TextEditingController chequeCtrl = TextEditingController(text: "");
    TextEditingController debtCtrl = TextEditingController(text: "");
    TextEditingController refCtrl = TextEditingController(text: "");

    void _recalculate(void Function(void Function()) setModalState) {
      double c = double.tryParse(cashCtrl.text) ?? 0.0;
      double q = double.tryParse(chequeCtrl.text) ?? 0.0;
      double d = double.tryParse(debtCtrl.text) ?? 0.0;
      chequeRef = refCtrl.text.trim();
      
      cashAmount = c;
      chequeAmount = q;
      debtAmount = d;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // شفافة للويب
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          double currentTotal = cashAmount + chequeAmount + debtAmount;
          bool isBalanced = (currentTotal - totalRequired).abs() < 1.0; 
          
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded, color: primaryBlue, size: 30),
                          const SizedBox(width: 10),
                          Text("تصريح بتفاصيل الدفع", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text("يرجى توضيح كيف قمت بتسديد مبلغ الطرد.", style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey.shade600)),
                      
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 15),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade100)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("المبلغ الإجمالي للطرد:", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue)),
                            Text("${NumberFormat('#,##0.00').format(totalRequired)} دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 16)),
                          ],
                        ),
                      ),

                      // 1. الدفع نقداً (Cash)
                      Text("المبلغ نقداً (Cash) دج", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 5),
                      TextField(
                        controller: cashCtrl, keyboardType: TextInputType.number,
                        onChanged: (v) => setModalState(() => _recalculate(setModalState)),
                        decoration: InputDecoration(prefixIcon: const Icon(Icons.money, color: Colors.green), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(vertical: 10)),
                      ),
                      const SizedBox(height: 15),

                      // 2. الدفع بشيك (Cheque)
                      Text("المبلغ عبر صك بنكي/بريدي (إن وجد) دج", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: chequeCtrl, keyboardType: TextInputType.number,
                              onChanged: (v) => setModalState(() => _recalculate(setModalState)),
                              decoration: InputDecoration(hintText: "المبلغ", prefixIcon: const Icon(Icons.receipt, color: Colors.purple), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(vertical: 10)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: refCtrl,
                              onChanged: (v) => setModalState(() => _recalculate(setModalState)),
                              decoration: InputDecoration(hintText: "رقم الصك", prefixIcon: const Icon(Icons.numbers, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(vertical: 10)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // 3. الباقي كدين (Debt)
                      Text("المبلغ المتبقي كدين (بالآجل) دج", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 5),
                      TextField(
                        controller: debtCtrl, keyboardType: TextInputType.number,
                        onChanged: (v) => setModalState(() => _recalculate(setModalState)),
                        decoration: InputDecoration(prefixIcon: const Icon(Icons.edit_note, color: Colors.orange), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(vertical: 10)),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // شريط التحقق من المجموع
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: isBalanced ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            Icon(isBalanced ? Icons.check_circle : Icons.warning_amber_rounded, color: isBalanced ? Colors.green : Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Text("مجموع المبالغ المدخلة: ${NumberFormat('#,##0').format(currentTotal)} دج", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isBalanced ? Colors.green.shade800 : Colors.red.shade800)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            disabledBackgroundColor: Colors.grey.shade300,
                          ),
                          onPressed: !isBalanced ? null : () async {
                            List<Map<String, dynamic>> payments = [];
                            if (cashAmount > 0) payments.add({"method": "cash", "amount": cashAmount});
                            if (chequeAmount > 0) payments.add({"method": "cheque", "amount": chequeAmount, "reference": chequeRef});
                            if (debtAmount > 0) payments.add({"method": "debt", "amount": debtAmount});

                            Navigator.pop(ctx); 
                            _showLoadingOverlay();
                            
                            bool success = await ApiService.customerDeclarePayment(item['id'], payments);
                            
                            if (mounted && Navigator.canPop(context)) Navigator.pop(context); 
                            
                            if (success) {
                              _showToast("✅ تم إرسال تصريح الدفع وتأكيد الاستلام للإدارة", successGreen);
                              _loadCustomerData(); 
                              
                              String adminPhone = "";
                              try {
                                final users = await ApiService.getAllUsers();
                                final adminUser = users.firstWhere((u) => u['role'] == 'admin', orElse: () => null);
                                if (adminUser != null && adminUser['phone'] != null) {
                                  adminPhone = adminUser['phone'].toString();
                                }
                              } catch (e) {
                                debugPrint("Could not fetch admin phone: $e");
                              }

                              if (adminPhone.isNotEmpty) {
                                String cleanPhone = adminPhone.replaceAll(RegExp(r'\D'), ''); 
                                if (cleanPhone.startsWith('0')) {
                                  cleanPhone = '213${cleanPhone.substring(1)}';
                                } else if (!cleanPhone.startsWith('213')) {
                                  cleanPhone = '213$cleanPhone'; 
                                }

                                String whatsappMsg = "🔔 *إشعار تصريح مالي جديد*\n\nالزبون: ${item['customer_name'] ?? _currentUsername}\nرقم الطلبية: ${item['tracking_number']}\nالمبلغ الكلي المصرّح به: ${NumberFormat('#,##0.00').format(currentTotal)} دج\n\nيرجى الدخول للنظام لمراجعة الطلب (قبول/تعديل).";
                                
                                final Uri whatsappUrl = Uri.parse("whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(whatsappMsg)}");
                                final Uri webUrl = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(whatsappMsg)}");
                                
                                try {
                                  if (await canLaunchUrl(whatsappUrl)) {
                                    await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                                  } else if (await canLaunchUrl(webUrl)) {
                                    await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                                  }
                                } catch (e) {
                                  debugPrint("WhatsApp Launch Error: $e");
                                }
                              }
                            } else {
                              _showToast("❌ حدث خطأ أثناء إرسال التصريح", Colors.red);
                            }
                          },
                          child: Text("تأكيد وإرسال للإدارة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      )
    );
  }

  // ==========================================================
  // 🤝 المصافحة الذكية الثانية (NFC)
  // ==========================================================
  void _startSmartNfcReceipt(Map<String, dynamic> item) async {
    // 🔥 الحماية من الويب: الـ NFC يعمل فقط على تطبيق الهاتف
    if (kIsWeb) {
      _showToast("خاصية NFC غير مدعومة في متصفح الويب. يمكنك الاستلام عبر التصريح اليدوي لاحقاً.", Colors.orange.shade800);
      return;
    }

    final trackingNum = item['tracking_number'];
    
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      _showToast("حساس NFC غير مفعل أو غير متوفر في هاتفك 📱", Colors.red);
      return;
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contactless_rounded, size: 80, color: primaryBlue),
            const SizedBox(height: 15),
            Text("المصافحة الثانية 🤝", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Text("يرجى تمرير بطاقة السائق لتأكيد الاستلام.\n(لن يتم خصم أي مبالغ حتى تقوم بالتصريح بها)", textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
            LinearProgressIndicator(color: primaryBlue, backgroundColor: primaryBlue.withOpacity(0.1)),
            const SizedBox(height: 15),
            TextButton(onPressed: () { NfcManager.instance.stopSession(); Navigator.pop(ctx); }, child: Text("إلغاء العملية", style: GoogleFonts.cairo(color: Colors.red)))
          ],
        ),
      ),
    );

    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
      onDiscovered: (NfcTag tag) async {
        NfcManager.instance.stopSession();
        if (!mounted) return;
        Navigator.pop(context); 

        List<int>? identifier;
        try {
          // 🔥 حل مشكلة الـ Object في Dart الجديدة
          final Map<dynamic, dynamic> rawTagData = (tag as dynamic).data as Map<dynamic, dynamic>;
          for (var value in rawTagData.values) {
            if (value is Map && value.containsKey('identifier')) {
              var rawId = value['identifier'];
              if (rawId is List) {
                identifier = rawId.map((e) => int.parse(e.toString())).toList();
                break;
              }
            }
          }
        } catch(e) { debugPrint("NFC Read Error: $e"); }

        if (identifier == null || identifier.isEmpty) {
          _showToast("❌ تعذر قراءة البطاقة، جرب مجدداً", Colors.red);
          return;
        }

        String driverNfcId = identifier.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();

        if (mounted) _showLoadingOverlay();
        
        bool success = await ApiService.performHandshake(driverNfcId, trackingNum);
        
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);

        if (success) {
          _showToast("✅ تمت المصافحة! تم تسجيل استلامك للطلب.", successGreen);
          _loadCustomerData(); 
        } else {
          _showToast("❌ فشل الربط: البطاقة ليست للسائق المكلف، أو يوجد خطأ!", Colors.red);
        }
      }
    );
  }

  void _showQuantityEditor(int productId, String productName) {
    TextEditingController qtyCtrl = TextEditingController(text: "${_quantities[productId] ?? 1}");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("تحديد الكمية: $productName", style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          decoration: InputDecoration(
            filled: true, 
            fillColor: bgGray, 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              int? val = int.tryParse(qtyCtrl.text);
              if (val != null && val > 0) {
                setState(() => _quantities[productId] = val);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
            child: Text("اعتماد", style: GoogleFonts.cairo()),
          )
        ],
      ),
    );
  }

  void _showCheckoutCartDialog() {
    double totalAmount = _cart.fold(0, (sum, item) => sum + (item['price'] * item['qty']));
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => CheckoutDialog(
          totalAmount: totalAmount,
          isProcessing: _isProcessingCheckout,
          onSubmit: (phone, wilaya, address, time, lat, lng) async {
            setDialogState(() => _isProcessingCheckout = true);

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cust_phone', phone);
            await prefs.setString('cust_wilaya', wilaya);
            await prefs.setString('cust_address', address);

            String randomTracking = "DANTE-PKG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

            bool success = await ApiService.createCustomerOrder({
              "tracking_number": randomTracking, "customer_name": _currentUsername, 
              "customer_phone": phone, "customer_wilaya": wilaya, "customer_address": address,
              "gps_latitude": lat, "gps_longitude": lng, "preferred_delivery_time": time, 
              "cash_amount": totalAmount, "company_id": 1, 
              "items": _cart.map((item) => {"name": item['name'], "qty": item['qty'], "price": item['price']}).toList() 
            });

            if (!mounted) return;
            Navigator.pop(ctx); 

            if (success) {
              setState(() => _cart.clear()); 
              _loadCustomerData(); 
              _showToast('✅ تم إرسال طلبك بنجاح!', successGreen);
            } else {
              _showToast('❌ فشل في إرسال الطلب، حاول لاحقاً', Colors.red);
            }
            setDialogState(() => _isProcessingCheckout = false);
          },
        )
      )
    );
  }

  // 🔥 دالة منفصلة ونظيفة لبناء الشارة
  Widget _statusBadge(Map<String, dynamic> item) {
    Color color = Colors.grey;
    String label = item['status'] ?? 'pending';
    String status = item['status'] ?? 'pending';
    String approvalStatus = item['approval_status'] ?? 'not_required';
    String paymentStatus = item['payment_status'] ?? 'unpaid';
    
    if (status == 'pending_approval' && approvalStatus == 'pending') {
      color = pendingPurple; label = "الموعد ينتظر موافقتك";
    } else if (status == 'delivered' && paymentStatus == 'awaiting_customer_payment') {
      color = Colors.red.shade600; label = "يرجى التصريح بالدفع"; 
    } else if (paymentStatus == 'pending_admin_verification') {
      color = Colors.orange.shade700; label = "جاري مراجعة الإدارة";
    } else {
      switch(status) {
        case 'pending': color = Colors.blueGrey; label = "قيد المراجعة"; break;
        case 'approved': color = Colors.blue; label = "تم الاعتماد"; break;
        case 'assigned': color = Colors.orange; label = "جاري التجهيز"; break;
        case 'picked_up': color = warningOrange; label = "في الطريق إليك"; break;
        case 'in_transit': color = warningOrange; label = "في الطريق إليك"; break; // إضافة in_transit
        case 'settled': color = successGreen; label = "مكتملة ومغلقة ✅"; break;
        case 'delivered': color = successGreen; label = "تم التوصيل"; break; // إضافة delivered
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), // استخدام withValues
      child: Text(label, style: GoogleFonts.cairo(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb; // 🔥 التحقق من الويب

    return Scaffold(
      backgroundColor: bgGray,
      appBar: AppBar(
        title: Text("DANTE TRACE", style: GoogleFonts.poppins(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
        backgroundColor: primaryBlue, elevation: 0, centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _initializeApp),
        ],
      ),
      drawer: _buildSideBar(), 
      floatingActionButton: _cart.isNotEmpty ? _buildFloatingCheckout() : null,
      body: RefreshIndicator(
        onRefresh: () async { await _loadProductsData(); await _loadCustomerData(); },
        color: primaryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildStatsSection(),
              
              Padding(
                padding: EdgeInsets.fromLTRB(isDesktop ? 60 : 20, 30, isDesktop ? 60 : 20, 15), // هوامش مرنة للويب
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("كتالوج المنتجات", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                  ],
                ),
              ),
              
              _buildProductCatalog(),
              
              _buildSectionTitle("تتبع الطرود الحالية 🚚", isDesktop),
              _isLoadingOrders ? _buildShimmerList() : _buildShipmentList(_activeOrders, isDesktop),

              _buildSectionTitle("سجل العمليات السابقة 📋", isDesktop),
              _isLoadingOrders ? _buildShimmerList() : _buildShipmentList(_historyOrders, isDesktop, isHistory: true),
              
              const SizedBox(height: 100), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.fromLTRB(25, 20, 25, 45),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(35)),
        boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))] // استخدام withValues
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("مرحباً بك مجدداً،", style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16)),
          Text("أ. $_currentUsername", style: GoogleFonts.cairo(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("يمكنك الآن تتبع طرودك في الوقت الحقيقي وتأكيد الاستلام عبر الـ NFC.", style: GoogleFonts.cairo(color: Colors.white60, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final isDesktop = kIsWeb;

    return Transform.translate(
      offset: const Offset(0, -25),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 20), // هوامش مرنة للويب
        child: Row(
          children: [
            _statItem("الإجمالي", _totalOrders.toString(), primaryBlue, Icons.inventory_2_rounded),
            const SizedBox(width: 12),
            _statItem("في الطريق", _inTransitOrders.toString(), warningOrange, Icons.local_shipping_rounded),
            const SizedBox(width: 12),
            _statItem("مكتملة", _deliveredOrders.toString(), successGreen, Icons.verified_rounded),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)] // استخدام withValues
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCatalog() {
    final isDesktop = kIsWeb;

    if (_isLoadingProducts) return _buildShimmerProducts();
    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal, 
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 15), // هوامش للويب
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final p = _products[index];
          final pId = p['id'];
          return ProductCatalogCard(
            product: p, currentQty: _quantities[pId] ?? 1,
            pColor: index % 2 == 0 ? primaryBlue : warningOrange, 
            pIcon: Icons.inventory_2_rounded,
            onAddQty: () => setState(() => _quantities[pId] = (_quantities[pId] ?? 1) + 1),
            onRemoveQty: () { if (_quantities[pId]! > 1) setState(() => _quantities[pId] = _quantities[pId]! - 1); },
            onEditQty: () => _showQuantityEditor(pId, p['name']),
            onAddToCart: () => _handleAddToCart(p, _quantities[pId] ?? 1),
          );
        },
      ),
    );
  }

  // 📦 بناء بطاقة تتبع الطلبية (متجاوبة للويب)
  Widget _buildShipmentList(List<dynamic> orders, bool isDesktop, {bool isHistory = false}) {
    if (orders.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Text("لا توجد طرود متاحة", style: GoogleFonts.cairo(color: Colors.grey)),
      ));
    }
    
    return isDesktop
        ? GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 60), // هوامش للويب
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.5, // ارتفاع البطاقة المناسب
            ),
            itemCount: orders.length,
            itemBuilder: (context, index) => _buildOrderCard(orders[index], isHistory),
          )
        : ListView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: orders.length,
            itemBuilder: (context, index) => _buildOrderCard(orders[index], isHistory),
          );
  }

  // 🃏 الكارد المستقل الخاص بالطلبية
  Widget _buildOrderCard(Map<String, dynamic> item, bool isHistory) {
    bool canHandshake = item['status'] == 'picked_up' || item['status'] == 'in_transit';
    bool isPendingApproval = item['status'] == 'pending_approval' && item['approval_status'] == 'pending';
    
    // 🔥 زر التصريح يظهر للزبون طالما الطرد تم إسناده أو خرج للميدان
    bool canDeclarePayment = (item['status'] == 'delivered' || item['status'] == 'picked_up' || item['status'] == 'in_transit' || item['status'] == 'assigned') && item['payment_status'] != 'pending_admin_verification' && item['payment_status'] != 'settled_with_company';
    
    bool isPaymentUnderReview = (item['payment_status'] == 'pending_admin_verification');

    Color cardBorderColor = Colors.transparent;
    if (isPendingApproval) cardBorderColor = pendingPurple;
    if (canDeclarePayment) cardBorderColor = Colors.orange.shade400; // تنبيه للتصريح
    if (!isHistory && !isPendingApproval && !canDeclarePayment) cardBorderColor = primaryBlue.withValues(alpha: 0.1); // استخدام withValues

    List<dynamic> itemsList = [];
    if (item['items'] is String) {
      try { itemsList = jsonDecode(item['items']); } catch(e) { itemsList = []; }
    } else if (item['items'] is List) {
      itemsList = item['items'];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: (isPendingApproval || canDeclarePayment) ? 2 : 1),
        boxShadow: [BoxShadow(color: isPendingApproval ? pendingPurple.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.03), blurRadius: 10)] // استخدام withValues
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(15),
            leading: CircleAvatar(
              backgroundColor: isPendingApproval ? pendingPurple.withValues(alpha: 0.1) : (isHistory ? Colors.grey.shade100 : primaryBlue.withValues(alpha: 0.1)), // استخدام withValues
              child: Icon(isHistory ? Icons.check_rounded : Icons.local_shipping_rounded, color: isPendingApproval ? pendingPurple : (isHistory ? Colors.grey : primaryBlue)),
            ),
            title: Text(item['tracking_number'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${item['amount']} - ${item['time']}", style: GoogleFonts.cairo(fontSize: 12)),
                if (item['scheduled_date'] != "غير محدد") 
                   Padding(
                     padding: const EdgeInsets.only(top: 4.0),
                     child: Row(
                       children: [
                         Icon(Icons.calendar_month, size: 12, color: darkBlue),
                         const SizedBox(width: 4),
                         Text("تاريخ التسليم: ${item['scheduled_date']}", style: GoogleFonts.cairo(fontSize: 11, color: darkBlue, fontWeight: FontWeight.bold)),
                       ],
                     ),
                   ),
              ],
            ),
            trailing: _statusBadge(item), // 🔥 استدعاء الدالة النظيفة
          ),
          
          if (itemsList.isNotEmpty && !isPendingApproval) ...[
            const Divider(height: 1),
            // 🔥 استخدام Expanded لمنع التمدد الخاطئ داخل GridView
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("📦 تفاصيل الشحنة:", style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      const SizedBox(height: 5),
                      ...itemsList.map((product) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 5, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(child: Text("${product['name']}", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600))),
                            Text("x${product['qty']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 12)),
                          ],
                        ),
                      ))
                    ],
                  ),
                ),
              ),
            ),
          ],

          // عرض السائق 
          if (item['driver_name'] != null && !isHistory && !isPaymentUnderReview) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(color: Colors.blue.shade50.withValues(alpha: 0.5)), // استخدام withValues
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.person, color: darkBlue, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("كابتن التوصيل: ${item['driver_name']}", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: darkBlue)),
                        if (item['driver_phone'] != null)
                          Text("الهاتف: ${item['driver_phone']}", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (item['driver_phone'] != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: successGreen, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12)),
                      onPressed: () => _callDriver(item['driver_phone']),
                      icon: const Icon(Icons.phone, size: 16),
                      label: Text("اتصال", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                ],
              ),
            ),
          ],

          // 🔥 زر التصريح بالدفع وتأكيد الاستلام
          if (canDeclarePayment && !isHistory) ...[
            const Divider(height: 1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(Icons.receipt_long_rounded),
                label: Text("تأكيد الاستلام والتصريح بالدفع", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => _showPaymentDeclarationSheet(item),
              ),
            ),
          ],
          
          // أزرار القبول والتأجيل للموعد
          if (isPendingApproval && !isHistory) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              decoration: BoxDecoration(color: pendingPurple.withValues(alpha: 0.05)), // استخدام withValues
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: pendingPurple, foregroundColor: Colors.white, elevation: 0),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: Text("قبول الموعد", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _handleCustomerApproval(item, true),
                    )
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      icon: const Icon(Icons.schedule, size: 16),
                      label: Text("تأجيل الموعد", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _handleCustomerApproval(item, false),
                    )
                  ),
                ],
              ),
            )
          ]
          else if (canHandshake && !isHistory) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () => _startSmartNfcReceipt(item),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: warningOrange.withValues(alpha: 0.05)), // استخدام withValues
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.nfc_rounded, color: warningOrange, size: 18),
                    const SizedBox(width: 8),
                    Text("مسح بطاقة السائق للاستلام (NFC)", style: GoogleFonts.cairo(color: warningOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            )
          ],
          
          if (isHistory) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () => _downloadReceipt(item['id']),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: successGreen.withValues(alpha: 0.05), // استخدام withValues
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_rounded, color: successGreen, size: 18),
                    const SizedBox(width: 8),
                    Text("تنزيل وصل الاستلام النهائي (PDF)", style: GoogleFonts.cairo(color: successGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            )
          ],

          if (!isHistory && !isPendingApproval && !canDeclarePayment && !isPaymentUnderReview) 
            Container(
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50.withValues(alpha: 0.3), // استخدام withValues
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.grey.shade200))
              ),
              child: OrderTimelineWidget(
                currentStatus: item['status'] ?? 'pending',
                approvalStatus: item['approval_status'] ?? 'not_required',
              ),
            )
        ],
      ),
    );
  }

  void _handleAddToCart(Map<String, dynamic> p, int qty) {
    setState(() {
      final index = _cart.indexWhere((item) => item['id'] == p['id']);
      if (index >= 0) { _cart[index]['qty'] += qty; }
      else { _cart.add({'id': p['id'], 'name': p['name'], 'price': p['price'], 'qty': qty}); }
    });
    _showToast("🛒 تمت إضافة ${p['name']} للسلة", successGreen);
  }

  Widget _buildFloatingCheckout() {
    return FloatingActionButton.extended(
      onPressed: _showCheckoutCartDialog,
      backgroundColor: successGreen,
      elevation: 5,
      icon: badges.Badge(
        badgeContent: Text(_cart.length.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
        child: const Icon(Icons.shopping_basket_rounded, color: Colors.white),
      ),
      label: Text("إتمام الطلب الآن", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  void _showToast(String msg, Color color) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.all(20),
    ));
  }

  void _showLoadingOverlay() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
  }

  Widget _buildSectionTitle(String title, bool isDesktop) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isDesktop ? 60 : 20, 30, isDesktop ? 60 : 20, 15),
      child: Text(title, style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue.withValues(alpha: 0.8))), // استخدام withValues
    );
  }

  Widget _buildSideBar() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: primaryBlue),
            accountName: Text(_currentUsername, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            accountEmail: Text("حساب زبون مميز", style: GoogleFonts.cairo()),
          ),
          
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8), 
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), 
              child: const Icon(Icons.inventory_rounded, color: Colors.green)
            ),
            title: Text("تأكيد استلام الطرود", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerDeliveryConfirmScreen()));
            }
          ),
          const Divider(),
          
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8), 
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), 
              child: const Icon(Icons.logout, color: Colors.red)
            ),
            title: Text("تسجيل الخروج", style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              _channel?.sink.close();
              ApiService.logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            }
          )
        ],
      )
    );
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
      child: Container(margin: const EdgeInsets.symmetric(horizontal: 20), height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))
    );
  }

  Widget _buildShimmerProducts() {
    return const Center(child: CircularProgressIndicator());
  }
}