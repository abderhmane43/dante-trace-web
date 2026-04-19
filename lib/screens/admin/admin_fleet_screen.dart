import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد مهم للويب
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nfc_manager/nfc_manager.dart'; 
import 'package:intl/intl.dart'; 

import '../../services/api_service.dart';
import '../../widgets/admin/fleet/driver_fleet_card.dart';

class AdminFleetScreen extends StatefulWidget {
  const AdminFleetScreen({super.key});

  @override
  State<AdminFleetScreen> createState() => _AdminFleetScreenState();
}

class _AdminFleetScreenState extends State<AdminFleetScreen> {
  // 🎨 الألوان (Pro Mode)
  final Color primaryGreen = const Color(0xFF2E7D32); // أخضر مالي
  final Color darkBlue = const Color(0xFF1E293B);
  final Color softBg = const Color(0xFFF8FAFC);

  bool _isLoading = true;
  List<dynamic> _fleetData = [];
  
  double _totalFleetMoney = 0.0;
  // 🔥 تم حذف المتغير _totalActiveMissions لأنه غير مستخدم لتنظيف الكود من التحذيرات الصفراء

  @override
  void initState() {
    super.initState();
    _fetchFleetData();
  }

  Future<void> _fetchFleetData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/fleet'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        
        // حساب الإجماليات للوحة التحكم العلوية
        double tempMoney = 0.0;
        
        for(var driver in data) {
           tempMoney += double.tryParse(driver['current_cash_balance']?.toString() ?? '0') ?? 0.0;
        }

        setState(() {
          _fleetData = data;
          _totalFleetMoney = tempMoney;
        });
      }
    } catch (e) {
      _showToast("تعذر جلب بيانات الأسطول", Colors.red.shade700);
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // 💰 المصافحة النهائية للويب: إدخال يدوي أو عبر قارئ USB
  // =========================================================================
  void _startWebSettlement() {
    final TextEditingController nfcManualCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.keyboard_alt_outlined, color: primaryGreen),
            const SizedBox(width: 10),
            Text("تصفية الخزينة (الويب)", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18, color: darkBlue)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("مرر بطاقة السائق على قارئ الـ USB أو أدخل رقم البطاقة يدوياً:", style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 15),
            TextField(
              controller: nfcManualCtrl,
              autofocus: true, // للالتقاط التلقائي من القارئ
              decoration: InputDecoration(
                labelText: "رقم البطاقة (NFC ID)",
                labelStyle: GoogleFonts.cairo(),
                filled: true,
                fillColor: softBg,
                prefixIcon: const Icon(Icons.nfc_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen)),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  _processSettlement(value.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              if (nfcManualCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _processSettlement(nfcManualCtrl.text.trim());
              }
            },
            child: Text("اعتماد التصفية", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 💰 المصافحة النهائية للهاتف: مسح بطاقة NFC
  // =========================================================================
  Future<void> _startNfcSettlement() async {
    // 🔥 الحماية: إذا كان التطبيق يعمل على الويب نفتح الإدخال اليدوي
    if (kIsWeb) {
      _startWebSettlement();
      return;
    }

    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      _showToast("حساس الـ NFC غير متوفر أو معطل في جهازك!", Colors.red.shade700);
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: primaryGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.wifi_tethering_rounded, size: 50, color: primaryGreen),
            ),
            const SizedBox(height: 24),
            Text("تصفية الخزينة (NFC)", style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: darkBlue)),
            const SizedBox(height: 12),
            Text(
              "يرجى تمرير بطاقة السائق خلف هاتفك ليتم سحب العهدة وإيداعها في الخزينة المركزية.", 
              style: GoogleFonts.cairo(color: Colors.grey.shade600, fontSize: 14), 
              textAlign: TextAlign.center
            ),
            const SizedBox(height: 30),
            LinearProgressIndicator(color: primaryGreen, backgroundColor: primaryGreen.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)
              ),
              onPressed: () { NfcManager.instance.stopSession(); Navigator.pop(ctx); },
              child: Text("إلغاء العملية", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
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
          // 🔥 الحل السحري لتخطي حماية الدارت الجديدة
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
          debugPrint("NFC Read Error");
        }

        if (identifier != null && identifier.isNotEmpty) {
          String scannedId = identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
          _processSettlement(scannedId);
        } else {
          _showToast("قراءة خاطئة للبطاقة، حاول مجدداً.", Colors.orange.shade800);
        }
      }
    );
  }

  Future<void> _processSettlement(String nfcId) async {
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => Center(child: CircularProgressIndicator(color: primaryGreen))
    );
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/admin/settle-driver/'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"driver_nfc_id": nfcId}),
      );

      if (mounted && Navigator.canPop(context)) Navigator.pop(context); 

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        String message = data['message'];
        if (data.containsKey('amount_settled')) {
           final double amount = double.tryParse(data['amount_settled']?.toString() ?? '0') ?? 0.0;
           final String formattedAmount = NumberFormat('#,##0.00').format(amount);
           message = "تمت التصفية بنجاح واستلام $formattedAmount دج";
        }

        _showToast(message, primaryGreen);
        _fetchFleetData(); 
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        _showToast(error['detail'] ?? "تعذرت عملية التصفية", Colors.red.shade700);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _showToast("انقطع الاتصال بالخادم المركزي", Colors.red.shade700);
    }
  }

  // دالة تأكيد استلام الأموال وإنهاء الطلبية (التأكيد اليدوي الاحتياطي)
  Future<void> _confirmDeliveryAndPayment(int orderId, String customerName) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator(color: primaryGreen)));
    
    bool success = await ApiService.updateOrderStatus(orderId, 'settled');
    
    if (mounted && Navigator.canPop(context)) Navigator.pop(context); 

    if (success) {
      _showToast("✅ تم إغلاق الطلب وتأكيد استلام أموال $customerName", primaryGreen);
      _fetchFleetData(); 
    } else {
      _showToast("❌ حدث خطأ أثناء إغلاق الطلب", Colors.red.shade700);
    }
  }

  void _showToast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
      backgroundColor: color, 
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(20),
      elevation: 10,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb; // 🔥 فحص الويب
    final String formattedTotalMoney = NumberFormat('#,##0.00').format(_totalFleetMoney);

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: Text("رادار الأسطول والعهد", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        // 🔥 إخفاء القائمة العلوية في الويب
        leading: isDesktop ? const SizedBox.shrink() : null,
        iconTheme: IconThemeData(color: darkBlue),
        actions: [
          IconButton(icon: Icon(Icons.sync_rounded, color: darkBlue), onPressed: _fetchFleetData, tooltip: "تحديث الرادار")
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNfcSettlement,
        backgroundColor: primaryGreen,
        elevation: 4,
        icon: Icon(isDesktop ? Icons.keyboard_alt_rounded : Icons.nfc_rounded, color: Colors.white), // 🔥 تغيير الأيقونة في الويب
        label: Text(isDesktop ? "تصفية (USB/يدوي)" : "تصفية الخزينة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 0), // مساحات واسعة للويب
        child: Column(
          children: [
            // 📊 لوحة التحكم العلوية السريعة
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: isDesktop ? const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)) : BorderRadius.zero,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5, offset: const Offset(0, 2))]
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.account_balance_wallet_rounded, color: Colors.orange.shade800),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("إجمالي العهدة في الميدان", style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text("$formattedTotalMoney دج", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: darkBlue)),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 10)),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.local_shipping_rounded, color: Colors.blue.shade700),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("السائقون النشطون", style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                              Text("${_fleetData.length}", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: darkBlue)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 🚚 قائمة السائقين
            Expanded(
              child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryGreen))
                : _fleetData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.airport_shuttle_rounded, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text("الأسطول غير نشط حالياً", style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: primaryGreen,
                      onRefresh: _fetchFleetData,
                      child: isDesktop
                        // 🔥 تصميم الـ GridView للويب لعدم تمدد البطاقات
                        ? GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, 
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                              childAspectRatio: 1.8, // ضبط الارتفاع لبطاقة السائق
                            ),
                            itemCount: _fleetData.length,
                            itemBuilder: (context, index) {
                              return DriverFleetCard(
                                driver: _fleetData[index],
                                onConfirmDelivery: _confirmDeliveryAndPayment,
                              );
                            },
                          )
                        // 🔥 التصميم الأصلي (ListView) للهاتف
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 90), 
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            itemCount: _fleetData.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: DriverFleetCard(
                                  driver: _fleetData[index],
                                  onConfirmDelivery: _confirmDeliveryAndPayment,
                                ),
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