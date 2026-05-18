import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; 
import 'package:nfc_manager/nfc_manager.dart'; 

import '../../services/api_service.dart';
import '../../widgets/admin/admin_drawer.dart'; 

class CollectorDashboardScreen extends StatefulWidget {
  const CollectorDashboardScreen({super.key});

  @override
  State<CollectorDashboardScreen> createState() => _CollectorDashboardScreenState();
}

class _CollectorDashboardScreenState extends State<CollectorDashboardScreen> {
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B); 
  final Color softBg = const Color(0xFFF8FAFC);
  final Color cardBorder = const Color(0xFFE2E8F0);
  
  bool _isLoading = true;
  String _userName = 'محصل ميداني';
  double _myCashBalance = 0.0;
  double _myCheckBalance = 0.0;

  List<dynamic> _driversWithCash = [];
  List<dynamic> _customerDebts = [];
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _fetchCollectorData();
  }

  void _triggerSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars(); 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: isError ? primaryRed : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(15),
      )
    );
  }

  void _showLoadingOverlay() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
  }

  Future<void> _fetchCollectorData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

      try {
        final profileRes = await http.get(Uri.parse('${ApiService.baseUrl}/users/me'), headers: headers).timeout(const Duration(seconds: 15));
        if (profileRes.statusCode == 200) {
          final profile = jsonDecode(utf8.decode(profileRes.bodyBytes));
          _userName = profile['first_name']?.toString() ?? profile['username']?.toString() ?? 'محصل';
          _myCashBalance = double.tryParse(profile['current_cash_balance']?.toString() ?? '0') ?? 0.0;
          _myCheckBalance = double.tryParse(profile['current_check_balance']?.toString() ?? '0') ?? 0.0;
        }
      } catch (e) {
        debugPrint("فشل جلب الملف الشخصي: $e");
      }

      try {
        final debtorsRes = await http.get(Uri.parse('${ApiService.baseUrl}/collector/debtors'), headers: headers).timeout(const Duration(seconds: 15));
        if (debtorsRes.statusCode == 200) {
          final debtorsData = jsonDecode(utf8.decode(debtorsRes.bodyBytes));
          _driversWithCash = debtorsData['drivers'] ?? [];
          _customerDebts = debtorsData['customers'] ?? [];
        } else {
           _driversWithCash = [];
           _customerDebts = [];
           debugPrint("خطأ في جلب الديون: ${debtorsRes.statusCode}");
        }
      } catch (e) {
         _driversWithCash = [];
         _customerDebts = [];
         debugPrint("عطل سيرفر أثناء جلب الديون: $e");
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastUpdated = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _triggerSnackBar("تأكد من استقرار اتصالك بالإنترنت", isError: true);
      }
    }
  }

  Future<void> _startNfcDriverCollection() async {
    if (kIsWeb) {
      _triggerSnackBar("خاصية NFC متاحة فقط في تطبيق الهاتف", isError: true);
      return;
    }

    bool isSupported = await NfcManager.instance.isAvailable();
    if (!isSupported) {
      _triggerSnackBar("حساس الـ NFC غير متوفر أو معطل!", isError: true);
      return;
    }

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
            Text("يرجى تمرير بطاقة السائق خلف هاتفك لمعاينة العهدة", style: GoogleFonts.cairo(color: Colors.grey.shade600), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            LinearProgressIndicator(color: primaryRed, backgroundColor: primaryRed.withValues(alpha: 0.1)),
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
          final dynamic dData = tag.data;
          List<dynamic> encodedList = dData.encode();
          if (encodedList.length >= 2 && encodedList[1] is List) {
            identifier = List<int>.from(encodedList[1]);
          }
        } catch(e) { debugPrint("NFC Read Error: $e"); }

        if (identifier != null && identifier.isNotEmpty) {
          String scannedId = identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
          _previewDriverCollection(scannedId);
        } else {
          _triggerSnackBar("لم نتمكن من قراءة البطاقة، حاول مجدداً.", isError: true);
        }
      }
    );
  }

  Future<void> _previewDriverCollection(String nfcId) async {
    _showLoadingOverlay();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/collector/preview-driver-collection'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"driver_nfc_id": nfcId}),
      );

      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _showDriverCollectionConfirmation(data, nfcId);
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        _triggerSnackBar(error['detail'] ?? "حدث خطأ", isError: true);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _triggerSnackBar("انقطع الاتصال بالسيرفر", isError: true);
    }
  }

  void _showDriverCollectionConfirmation(Map<String, dynamic> data, String nfcId) {
    final double cash = double.tryParse(data['cash_to_collect']?.toString() ?? '0') ?? 0.0;
    final double check = double.tryParse(data['check_to_collect']?.toString() ?? '0') ?? 0.0;
    final String formattedCash = NumberFormat('#,##0.00').format(cash);
    final String formattedCheck = NumberFormat('#,##0.00').format(check);
    final int ordersCount = data['orders_count'] ?? 0;
    final String driverName = data['driver_name']?.toString() ?? 'السائق';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Icon(Icons.account_balance_wallet_rounded, color: darkBlue, size: 45),
            const SizedBox(height: 10),
            Text("مراجعة العهدة المالية", style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: darkBlue)),
            Text("الموظف: $driverName", style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("كاش", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                            const SizedBox(width: 5),
                            Icon(Icons.payments_rounded, color: Colors.green.shade800, size: 16),
                          ],
                        ),
                        const SizedBox(height: 5),
                        FittedBox(fit: BoxFit.scaleDown, child: Text("$formattedCash دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade900))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
                    decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purple.shade200)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("شيكات", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.purple.shade800)),
                            const SizedBox(width: 5),
                            Icon(Icons.receipt_long_rounded, color: Colors.purple.shade800, size: 16),
                          ],
                        ),
                        const SizedBox(height: 5),
                        FittedBox(fit: BoxFit.scaleDown, child: Text("$formattedCheck دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple.shade900))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, color: darkBlue, size: 18),
                  const SizedBox(width: 8),
                  Text("عدد الطرود المحصّلة: $ordersCount طرد", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue)),
                ],
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: darkBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  Navigator.pop(ctx);
                  _executeDriverCollection(nfcId);
                },
                icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                label: Text("تأكيد استلام العهدة", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _executeDriverCollection(String nfcId) async {
    _showLoadingOverlay();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/collector/collect-from-driver'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"driver_nfc_id": nfcId}),
      );

      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _triggerSnackBar(data['message']?.toString() ?? "تم");
        _fetchCollectorData();
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        _triggerSnackBar(error['detail']?.toString() ?? "حدث خطأ", isError: true);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _triggerSnackBar("انقطع الاتصال بالسيرفر", isError: true);
    }
  }

  Future<void> _collectFromCustomer(int shipmentId, double amount, String customerName) async {
    final String formattedAmount = NumberFormat('#,##0.00').format(amount);

    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.monetization_on_rounded, color: Colors.green.shade800),
            const SizedBox(width: 10),
            Text("تأكيد استلام الدين", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 16)),
          ],
        ),
        content: Text("هل أنت متأكد أنك استلمت مبلغ ($formattedAmount دج) نقداً من الزبون: $customerName؟", style: GoogleFonts.cairo(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
        _triggerSnackBar("تم تحصيل الدين بنجاح! 💸");
        _fetchCollectorData();
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        _triggerSnackBar(error['detail']?.toString() ?? "حدث خطأ", isError: true);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _triggerSnackBar("انقطع الاتصال بالسيرفر", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: darkBlue,
        centerTitle: true,
        title: Text("لوحة المحصل الميداني", style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: darkBlue)),
      ),
      drawer: const AdminDrawer(), 
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNfcDriverCollection,
        backgroundColor: darkBlue,
        icon: const Icon(Icons.nfc_rounded, color: Colors.white),
        label: Text("استلام عهدة سائق", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCollectorData,
        color: primaryRed,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : _buildMainContent(),
      ),
    );
  }

  Widget _buildMainContent() {
    final String formattedCash = NumberFormat('#,##0.00').format(_myCashBalance);
    final String formattedCheck = NumberFormat('#,##0.00').format(_myCheckBalance);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [darkBlue, const Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: darkBlue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("مرحباً، $_userName 👋", style: GoogleFonts.cairo(fontSize: 14, color: Colors.white70)),
              Text("العهدة المالية الخاصة بك", style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Icon(Icons.payments_rounded, color: Colors.green.shade400, size: 24),
                          const SizedBox(height: 5),
                          Text("نقداً (كاش)", style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
                          FittedBox(fit: BoxFit.scaleDown, child: Text("$formattedCash دج", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_rounded, color: Colors.purple.shade300, size: 24),
                          const SizedBox(height: 5),
                          Text("شيكات", style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
                          FittedBox(fit: BoxFit.scaleDown, child: Text("$formattedCheck دج", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        
        const SizedBox(height: 30),
        
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: primaryRed, size: 24),
            const SizedBox(width: 10),
            Text("ديون الزبائن المطلوبة", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
          ],
        ),
        const SizedBox(height: 10),
        if (_customerDebts.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: cardBorder)),
            child: Center(child: Text("لا توجد ديون زبائن مسندة إليك حالياً ✅", style: GoogleFonts.cairo(color: Colors.grey.shade500, fontWeight: FontWeight.bold))),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _customerDebts.length,
            itemBuilder: (ctx, i) {
              final debt = _customerDebts[i] ?? {};
              final double amount = double.tryParse(debt['debt_amount']?.toString() ?? '0') ?? 0.0;
              final String fAmount = NumberFormat('#,##0.00').format(amount);
              final String customerName = debt['customer_name']?.toString() ?? 'مجهول';
              final String address = debt['address']?.toString() ?? '-';

              return Card(
                elevation: 0, margin: const EdgeInsets.only(bottom: 10),
                color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cardBorder)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  leading: CircleAvatar(backgroundColor: Colors.red.shade50, child: Icon(Icons.person, color: primaryRed)),
                  title: Text(customerName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  subtitle: Text(address, style: GoogleFonts.cairo(fontSize: 12)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () => _collectFromCustomer(debt['shipment_id'], amount, customerName),
                    child: Text("استلام $fAmount", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              );
            },
          ),

        const SizedBox(height: 30),

        Row(
          children: [
            Icon(Icons.directions_car_filled_rounded, color: Colors.orange.shade800, size: 24),
            const SizedBox(width: 10),
            Text("سائقون يملكون عهدة", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
          ],
        ),
        const SizedBox(height: 10),
        if (_driversWithCash.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: cardBorder)),
            child: Center(child: Text("خزائن جميع السائقين مصفاة حالياً ✅", style: GoogleFonts.cairo(color: Colors.grey.shade500, fontWeight: FontWeight.bold))),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _driversWithCash.length,
            itemBuilder: (ctx, i) {
              final driver = _driversWithCash[i] ?? {};
              final double balance = double.tryParse(driver['balance']?.toString() ?? '0') ?? 0.0;
              final String fBalance = NumberFormat('#,##0.00').format(balance);
              final String driverName = driver['name']?.toString() ?? 'سائق';
              final String phone = driver['phone']?.toString() ?? '-';

              return Card(
                elevation: 0, margin: const EdgeInsets.only(bottom: 10),
                color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cardBorder)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: Icon(Icons.local_shipping, color: Colors.orange.shade800)),
                  title: Text(driverName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  subtitle: Text("الهاتف: $phone", style: GoogleFonts.cairo(fontSize: 12)),
                  trailing: Text("$fBalance دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 14)),
                ),
              );
            },
          ),
      ],
    );
  }
}