import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:web_socket_channel/web_socket_channel.dart'; 
import 'package:intl/intl.dart'; 
import 'package:url_launcher/url_launcher.dart'; 

import '../../services/api_service.dart';
import '../shared/login_screen.dart'; 

class CollectorDashboardScreen extends StatefulWidget {
  const CollectorDashboardScreen({super.key});

  @override
  State<CollectorDashboardScreen> createState() => _CollectorDashboardScreenState();
}

class _CollectorDashboardScreenState extends State<CollectorDashboardScreen> {
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B);
  final Color successGreen = const Color(0xFF1B5E20);
  final Color bgGray = const Color(0xFFF8FAFC);
  
  bool _isLoading = true;
  double _myBalance = 0.0;
  String _collectorName = "المحصل";
  
  List<dynamic> _drivers = [];
  List<dynamic> _customers = [];
  
  WebSocketChannel? _channel; 

  @override
  void initState() {
    super.initState();
    _fetchCollectorData();
    _connectWebSocket(); 
  }

  @override
  void dispose() {
    _channel?.sink.close(); 
    super.dispose();
  }

  // ==========================================
  // 📡 الاتصال الحي بالسيرفر (WebSocket)
  // ==========================================
  void _connectWebSocket() {
    try {
      String wsUrl = ApiService.baseUrl.replaceFirst('https', 'wss').replaceFirst('http', 'ws');
      _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws'));

      _channel!.stream.listen(
        (message) {
          if (message == "NEW_ORDER" || message == "STATUS_UPDATE") {
            _fetchCollectorData(); 
            if (mounted) {
              _showToast("تحديث جديد في المهام والديون 🔄", Colors.blue.shade700);
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

  Future<void> _fetchCollectorData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=utf-8'};

      final results = await Future.wait([
        http.get(Uri.parse('${ApiService.baseUrl}/users/me'), headers: headers),
        http.get(Uri.parse('${ApiService.baseUrl}/collector/debtors'), headers: headers),
      ]);

      if (mounted) {
        setState(() {
          if (results[0].statusCode == 200) {
            final me = jsonDecode(utf8.decode(results[0].bodyBytes));
            _myBalance = double.tryParse(me['current_cash_balance']?.toString() ?? '0') ?? 0.0;
            _collectorName = me['first_name'] ?? me['username'] ?? "المحصل";
          }
          if (results[1].statusCode == 200) {
            final data = jsonDecode(utf8.decode(results[1].bodyBytes));
            _drivers = data['drivers'] ?? [];
            _customers = data['customers'] ?? [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showToast("تعذر الاتصال بالسيرفر", Colors.red);
    }
  }

  // ==========================================
  // 💬 دوال التواصل (واتساب + اتصال)
  // ==========================================
  Future<void> _launchContact(String phone, {bool isWhatsApp = false}) async {
    if (phone.isEmpty || phone == '-') {
      _showToast("رقم الهاتف غير متوفر", Colors.orange);
      return;
    }

    String cleanPhone = phone.replaceAll(RegExp(r'\D'), ''); 
    if (cleanPhone.startsWith('0')) cleanPhone = '213${cleanPhone.substring(1)}';
    
    Uri url;
    if (isWhatsApp) {
      url = Uri.parse("whatsapp://send?phone=$cleanPhone");
    } else {
      url = Uri.parse("tel:+$cleanPhone");
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (isWhatsApp) {
        url = Uri.parse("https://wa.me/$cleanPhone");
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showToast("تعذر تنفيذ الإجراء", Colors.red);
      }
    } catch (e) {
      _showToast("حدث خطأ أثناء الفتح", Colors.red);
    }
  }

  // ==========================================
  // 📡 دالة استلام الأموال من السائق عبر NFC
  // ==========================================
  Future<void> _startNfcDriverCollection() async {
    // 🔥 حماية إذا تم فتح الشاشة من الويب
    if (kIsWeb) {
      _showToast("خاصية NFC متاحة فقط في تطبيق الهاتف", Colors.orange.shade800);
      return;
    }

    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      _showToast("حساس الـ NFC غير متوفر أو معطل!", Colors.red);
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_tethering, size: 50, color: Colors.blue),
            ),
            const SizedBox(height: 15),
            Text("جاهز للاستلام 💳", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
            const SizedBox(height: 10),
            Text("يرجى تمرير بطاقة السائق خلف هاتفك لتبادل العهدة المالية بشكل آمن", style: GoogleFonts.cairo(color: Colors.grey.shade600), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () { NfcManager.instance.stopSession(); Navigator.pop(ctx); },
              child: Text("إلغاء العملية", style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );

    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
      onDiscovered: (NfcTag tag) async {
        NfcManager.instance.stopSession();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context); 

        List<int>? identifier;
        try {
          // 🔥 الحل النهائي لمشكلة الخط الأحمر في Dart
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
        } catch(e) {
          debugPrint("NFC Read Error: $e");
        }

        if (identifier != null && identifier.isNotEmpty) {
          String scannedId = identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
          _processDriverCollection(scannedId);
        } else {
          _showToast("لم نتمكن من قراءة البطاقة.", Colors.orange.shade800);
        }
      }
    );
  }

  Future<void> _processDriverCollection(String nfcId) async {
    _showLoadingOverlay();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/collector/collect-from-driver'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"driver_nfc_id": nfcId}),
      );

      if (mounted && Navigator.canPop(context)) Navigator.pop(context); // إغلاق التحميل

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _showToast(data['message'], successGreen);
        _fetchCollectorData(); // تحديث الواجهة
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        _showToast(error['detail'] ?? "حدث خطأ", Colors.red);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _showToast("انقطع الاتصال بالسيرفر", Colors.red);
    }
  }

  // ==========================================
  // 💵 دالة تحصيل ديون الزبائن
  // ==========================================
  Future<void> _collectFromCustomer(int shipmentId, double amount, String customerName) async {
    final String formattedAmount = NumberFormat('#,##0.00').format(amount);

    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.monetization_on_rounded, color: successGreen),
            const SizedBox(width: 10),
            Text("تأكيد استلام الدين", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 16)),
          ],
        ),
        content: Text("هل أنت متأكد أنك استلمت مبلغ ($formattedAmount دج) نقداً من الزبون: $customerName؟", style: GoogleFonts.cairo(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: successGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("نعم، استلمت المبلغ", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    _showLoadingOverlay();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/collector/collect-from-customer/$shipmentId'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=utf-8'},
      );

      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      if (response.statusCode == 200) {
        _showToast("تم تحصيل الدين بنجاح! 💸", successGreen);
        _fetchCollectorData();
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        _showToast(error['detail'] ?? "حدث خطأ", Colors.red);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _showToast("انقطع الاتصال بالسيرفر", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGray,
      appBar: AppBar(
        title: Text("بوابة التحصيل الميداني 💼", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ApiService.logout();
              if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNfcDriverCollection,
        backgroundColor: darkBlue,
        icon: const Icon(Icons.nfc_rounded, color: Colors.white),
        label: Text("استلام من السائقين (NFC)", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCollectorData,
        color: primaryRed,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 90), // مساحة للزر العائم
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: [
            Container(
              color: darkBlue,
              padding: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildWalletCard(),
              ),
            ),
            
            if (_isLoading) 
              _buildShimmer()
            else ...[
              const SizedBox(height: 10),
              // 🚚 قسم السائقين
              _buildSectionTitle("أموال معلقة لدى السائقين 🚚", Colors.orange.shade800),
              if (_drivers.isEmpty) _buildEmptyState("لا توجد أموال مع السائقين حالياً")
              else ..._drivers.map((driver) => _buildDriverCard(driver)),

              const SizedBox(height: 15),

              // 👥 قسم ديون الزبائن
              _buildSectionTitle("ديون الزبائن المكلف بها 👥", primaryRed),
              if (_customers.isEmpty) _buildEmptyState("لم يتم تكليفك بتحصيل أي ديون")
              else ..._customers.map((customer) => _buildCustomerCard(customer)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard() {
    final String formattedBalance = NumberFormat('#,##0.00').format(_myBalance);
    
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryRed, const Color(0xFF991B1B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primaryRed.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white)),
              const SizedBox(width: 15),
              Expanded(child: Text("مرحباً بك، $_collectorName", style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 20),
          Text("العهدة الحالية (لتسليمها للإدارة):", style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text("$formattedBalance دج", style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(title, style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
    );
  }

  // بطاقة السائق (NFC Required)
  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final amount = double.tryParse(driver['balance']?.toString() ?? '0') ?? 0.0;
    final String formattedAmount = NumberFormat('#,##0.00').format(amount);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: Icon(Icons.local_shipping_rounded, color: Colors.orange.shade700)),
        title: Text(driver['name'] ?? 'سائق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("المبلغ المحتجز: $formattedAmount دج", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Row(
              children: [
                InkWell(
                  onTap: () => _launchContact(driver['phone']?.toString() ?? '', isWhatsApp: false),
                  child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)), child: Icon(Icons.call, size: 14, color: Colors.blue.shade700)),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _launchContact(driver['phone']?.toString() ?? '', isWhatsApp: true),
                  child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)), child: Icon(Icons.chat_bubble_rounded, size: 14, color: Colors.green.shade700)),
                ),
              ],
            )
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: darkBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.nfc_rounded, color: darkBlue, size: 24),
        ),
        onTap: _startNfcDriverCollection, 
      ),
    );
  }

  // بطاقة الزبون المديون (Manual Collection)
  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    final amount = double.tryParse(customer['debt_amount']?.toString() ?? '0') ?? 0.0;
    final String formattedAmount = NumberFormat('#,##0.00').format(amount);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.red.shade100), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)]),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: Colors.red.shade50, child: Icon(Icons.person_rounded, color: primaryRed)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer['customer_name'] ?? 'زبون', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 15)),
                      Text("الدين: $formattedAmount دج", style: GoogleFonts.poppins(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _launchContact(customer['phone']?.toString() ?? '', isWhatsApp: false),
                  child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.call, size: 16, color: Colors.blue.shade700)),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _launchContact(customer['phone']?.toString() ?? '', isWhatsApp: true),
                  child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.green.shade700)),
                ),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Expanded(child: Text(customer['address'] ?? 'غير محدد', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600))),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: successGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10)
                ),
                onPressed: () => _collectFromCustomer(customer['shipment_id'], amount, customer['customer_name']),
                icon: const Icon(Icons.monetization_on_rounded, size: 18),
                label: Text("تأكيد استلام الدين من الزبون", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
              child: Icon(Icons.check_circle_outline_rounded, size: 50, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 15),
            Text(msg, style: GoogleFonts.cairo(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(3, (i) => Shimmer.fromColors(
          baseColor: Colors.grey.shade200, highlightColor: Colors.white,
          child: Container(height: 120, margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15))),
        )),
      ),
    );
  }

  void _showLoadingOverlay() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
  }

  void _showToast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)), 
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(20),
    ));
  }
}