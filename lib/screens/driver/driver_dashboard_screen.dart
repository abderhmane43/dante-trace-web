import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد فحص الويب
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nfc_manager/nfc_manager.dart'; 
import 'package:intl/intl.dart'; 

import '../../services/api_service.dart';
import '../shared/login_screen.dart';
import '../../widgets/driver/driver_mission_card.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final Color primaryBlue = const Color(0xFF1E3A8A); 
  final Color backgroundGray = const Color(0xFFF4F7F9);
  final Color successGreen = const Color(0xFF2E7D32);
  final Color warningOrange = const Color(0xFFEF6C00);
  final Color primaryRed = const Color(0xFFD32F2F); 
  final Color darkBlue = const Color(0xFF1E293B); 
  final Color pendingPurple = const Color(0xFF9C27B0);

  bool _isLoading = true;
  String _driverName = "أيها السائق";
  List<dynamic> _activeMissions = [];
  
  WebSocketChannel? _channel; 

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadDriverProfile();
    await _fetchDriverMissions();
    _connectWebSocket(); 
  }

  @override
  void dispose() {
    _channel?.sink.close(); 
    super.dispose();
  }

  void _connectWebSocket() {
    try {
      final wsUrl = ApiService.baseUrl.replaceFirst('https', 'wss').replaceFirst('http', 'ws') + "/ws";
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen((message) {
        if (message == "STATUS_UPDATE" || message.contains("ASSIGNED")) {
          _fetchDriverMissions(showLoader: false);
        }
      }, onDone: () {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _connectWebSocket();
        });
      });
    } catch (e) {
      debugPrint("WS Connection Error: $e");
    }
  }

  Future<void> _loadDriverProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _driverName = prefs.getString('username') ?? "أيها السائق";
      });
    }
  }

  Future<void> _fetchDriverMissions({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) setState(() => _isLoading = true);
    
    try {
      final tasks = await ApiService.getDriverAssignedTasks();

      if (!mounted) return;

      setState(() {
        // 🔥 السائق يرى الطرود التي لم يوصلها بعد فقط
        _activeMissions = tasks.where((t) => t['delivery_status'] != 'delivered' && t['delivery_status'] != 'settled').toList();
      });
    } catch (e) {
      debugPrint("Driver Fetch Error: $e");
      if (mounted) _showToast("⚠️ خطأ في تزامن البيانات، جاري المحاولة...", Colors.orange.shade800);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startNfcAction(String trackingNumber, String actionType) async {
    // 🔥 الحماية من الويب: الـ NFC يعمل فقط على تطبيق الهاتف
    if (kIsWeb) {
      _showToast("خاصية مسح البطاقات غير مدعومة في متصفح الويب. الرجاء استخدام تطبيق الهاتف.", Colors.orange.shade800);
      return;
    }

    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        _showToast("NFC غير متوفر أو معطل في هاتفك!", Colors.red);
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
              Icon(Icons.contactless_rounded, size: 70, color: primaryRed),
              const SizedBox(height: 15),
              Text(
                actionType == 'pickup' ? "تأكيد استلام الطرد من المخزن" : "تأكيد التسليم النهائي للزبون",
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text("مرر بطاقة الشخص المعني (NFC) خلف الهاتف للإغلاق", style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  NfcManager.instance.stopSession();
                  Navigator.pop(ctx);
                },
                child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
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
            // 🔥 حل مشكلة الـ Object في Dart 3 الذي ظهر في الـ Terminal
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

          if (identifier != null && identifier.isNotEmpty) {
            String scannedId = identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();

            _showLoadingOverlay();
            final prefs = await SharedPreferences.getInstance();
            final token = prefs.getString('auth_token') ?? '';
            
            final response = await http.put(
              Uri.parse('${ApiService.baseUrl}/shipments/nfc-handshake/'),
              headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
              body: jsonEncode({"driver_nfc_id": scannedId, "tracking_number": trackingNumber}),
            );

            if (mounted) Navigator.pop(context); 

            if (response.statusCode == 200) {
              final resData = jsonDecode(utf8.decode(response.bodyBytes));
              _showToast(resData['message'], successGreen);
              _fetchDriverMissions(); 
            } else {
              final resData = jsonDecode(utf8.decode(response.bodyBytes));
              _showToast(resData['detail'] ?? "حدث خطأ مرفوض", Colors.red);
            }
          } else {
            _showToast("لم نتمكن من قراءة البطاقة.", Colors.orange.shade800);
          }
        }
      );
    } catch (e) {
      _showToast("خطأ غير متوقع في حساس NFC", Colors.red);
    }
  }

  // ==========================================
  // 📦 رسالة تأكيد التوصيل (بدون أموال) 🔥
  // ==========================================
  void _confirmDelivery(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: successGreen),
            const SizedBox(width: 10),
            Text("تأكيد التسليم الميداني", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          "هل أنت متأكد من تسليم الطرد رقم (${order['tracking_number']}) للزبون؟\n(بمجرد التأكيد، ستنتهي مهمتك مع هذا الطرد)",
          style: GoogleFonts.cairo(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: successGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              _showLoadingOverlay();
              
              bool success = await ApiService.updateOrderStatus(order['id'], 'delivered');
              
              if (mounted && Navigator.canPop(context)) Navigator.pop(context);
              
              if (success) {
                _showToast("✅ تم التوصيل بنجاح! أحسنت عملاً.", successGreen);
                _fetchDriverMissions();
              } else {
                _showToast("❌ فشل الاتصال بالسيرفر", Colors.red);
              }
            }, 
            child: Text("نعم، تم التسليم", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold))
          )
        ],
      )
    );
  }

  void _showLoadingOverlay() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
  }

  void _logout() async {
    _channel?.sink.close();
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  void _showToast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.all(20),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb; // متغير لضبط هوامش الويب

    return Scaffold(
      backgroundColor: backgroundGray,
      appBar: AppBar(
        title: Text("لوحة القيادة الميدانية", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Icon(Icons.circle, color: _channel != null ? Colors.greenAccent : Colors.redAccent, size: 12),
          ),
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _logout),
        ],
      ),
      body: RefreshIndicator(
        color: primaryBlue,
        onRefresh: () => _fetchDriverMissions(showLoader: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // تفعيل التمرير المطلق
          slivers: [
            SliverToBoxAdapter(child: _buildDriverHeader(isDesktop)),
            
            // 🔥 تم إصلاح مشكلة التمرير هنا
            SliverToBoxAdapter(
              child: _isLoading 
                ? _buildShimmerLoading(isDesktop)
                : _buildMissionsList(isDesktop),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDriverHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.fromLTRB(isDesktop ? 60 : 20, 20, isDesktop ? 60 : 20, 35), // هوامش للويب
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryBlue, const Color(0xFF152A63)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(35)),
        boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))] // استخدام withValues
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: Colors.white24)), // استخدام withValues
                child: const Icon(Icons.drive_eta_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("كابتن / $_driverName", style: GoogleFonts.cairo(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("نظام الرادار المباشر مفعل 📡", style: GoogleFonts.cairo(color: Colors.blue.shade200, fontSize: 12)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(20), 
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))] // استخدام withValues
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn("المهام الحالية", "${_activeMissions.length}", Icons.assignment_rounded, warningOrange),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatColumn(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF1E293B))),
        Text(title, style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMissionsList(bool isDesktop) {
    if (_activeMissions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 50.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.coffee_rounded, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 15),
              Text("لا توجد طرود بانتظار التوصيل!", style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              Text("الرادار يعمل، ستظهر المهام هنا فور\nإسنادها إليك من قِبل الإدارة 📡", textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey.shade500, height: 1.5)),
            ],
          ),
        ),
      );
    }

    return isDesktop
      ? GridView.builder(
          padding: const EdgeInsets.fromLTRB(60, 20, 60, 80),
          physics: const NeverScrollableScrollPhysics(), 
          shrinkWrap: true, 
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, 
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.2, 
          ),
          itemCount: _activeMissions.length,
          itemBuilder: (context, index) {
            return DriverMissionCard(
              order: _activeMissions[index],
              onDeliver: () => _confirmDelivery(_activeMissions[index]), 
              onPickUp: () {
                _startNfcAction(_activeMissions[index]['tracking_number'], 'pickup');
              },
            );
          },
        )
      : ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
          physics: const NeverScrollableScrollPhysics(), 
          shrinkWrap: true, 
          itemCount: _activeMissions.length,
          itemBuilder: (context, index) {
            return DriverMissionCard(
              order: _activeMissions[index],
              onDeliver: () => _confirmDelivery(_activeMissions[index]), 
              onPickUp: () {
                _startNfcAction(_activeMissions[index]['tracking_number'], 'pickup');
              },
            );
          },
        );
  }

  Widget _buildShimmerLoading(bool isDesktop) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
      child: isDesktop 
        ? GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
            physics: const NeverScrollableScrollPhysics(), shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.2),
            itemCount: 4,
            itemBuilder: (_, __) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20), itemCount: 3, physics: const NeverScrollableScrollPhysics(), shrinkWrap: true,
            itemBuilder: (_, __) => Container(height: 160, margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
          ),
    );
  }
}