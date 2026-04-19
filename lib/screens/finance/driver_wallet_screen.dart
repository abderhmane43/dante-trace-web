import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد فحص الويب
import 'package:google_fonts/google_fonts.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  double _cashBalance = 0.0;
  List<dynamic> _heldCheques = [];
  bool _isLoading = true;
  bool _isProcessingExpense = false;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  // ==========================================
  // 📥 جلب بيانات العهدة المباشرة (النسخة الحية - لا كاش)
  // ==========================================
  Future<void> _loadWalletData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // 🚀 استخدام المسار المباشر الجديد بدلاً من جلب كل المستخدمين
      final currentUserData = await ApiService.getMyProfile();
      
      if (mounted && currentUserData != null) {
        setState(() {
          // 🛡️ تحويل آمن للبيانات المالية
          final rawCash = currentUserData['current_cash_balance']?.toString() ?? '0';
          _cashBalance = double.tryParse(rawCash) ?? 0.0;
          _heldCheques = currentUserData['payments_held'] ?? []; 
        });
      }
    } catch (e) {
      debugPrint("❌ خطأ في جلب العهدة: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // 💸 نافذة تسجيل مصروف (بنزين، صيانة)
  // ==========================================
  void _showExpenseDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.local_gas_station, color: Colors.orange),
                ),
                const SizedBox(width: 10),
                Text("تسجيل مصروف", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.isEmpty) ? "أدخل المبلغ" : null,
                    decoration: InputDecoration(
                      labelText: "المبلغ (دج)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: descController,
                    validator: (v) => (v == null || v.isEmpty) ? "أدخل السبب" : null,
                    decoration: InputDecoration(
                      labelText: "السبب (مثلاً: مازوت)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.edit_note),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isProcessingExpense ? null : () => Navigator.pop(ctx), 
                child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold))
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isProcessingExpense ? null : () async {
                  if (formKey.currentState!.validate()) {
                    setDialogState(() => _isProcessingExpense = true);
                    
                    final success = await ApiService.submitDriverExpense(
                      double.parse(amountController.text),
                      descController.text,
                    );
                    
                    if (!mounted) return;

                    setDialogState(() => _isProcessingExpense = false);
                    Navigator.pop(ctx);
                    
                    if (success) {
                      _loadWalletData(); 
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ تم رفع طلب المصروف للإدارة", style: GoogleFonts.cairo()), backgroundColor: Colors.green));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ فشل إرسال الطلب", style: GoogleFonts.cairo()), backgroundColor: Colors.red));
                    }
                  }
                },
                child: _isProcessingExpense 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text("إرسال للإدارة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  // ==========================================
  // 🤝 نقل العهدة بمصافحة الـ NFC
  // ==========================================
  Future<void> _startNFCTransfer() async {
    // 🔥 الحماية من الويب
    if (kIsWeb) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("⚠️ خاصية NFC غير مدعومة في متصفح الويب. الرجاء استخدام تطبيق الهاتف لنقل العهدة.", style: GoogleFonts.cairo()), backgroundColor: Colors.orange.shade800));
      return;
    }

    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("⚠️ حساس الـ NFC غير مفعل في هاتفك!", style: GoogleFonts.cairo()), backgroundColor: Colors.red));
      return;
    }

    if (_cashBalance <= 0 && _heldCheques.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("⚠️ عهدتك فارغة بالفعل!", style: GoogleFonts.cairo()), backgroundColor: Colors.orange));
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container( 
        padding: const EdgeInsets.all(30),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nfc_rounded, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text("نقل العهدة المالية", style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("قم بتقريب هاتفك من بطاقة الإدمن أو المُحصّل لتسليمه الأموال وتبرئة ذمتك.", textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 30),
            const LinearProgressIndicator(color: Colors.blue),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () { NfcManager.instance.stopSession(); Navigator.pop(ctx); },
              child: Text("إلغاء العملية", style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );

    // 🔥 المحرك الآمن المقاوم للأخطاء الحمراء (tag.data)
    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
      onDiscovered: (NfcTag tag) async {
        NfcManager.instance.stopSession();
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context); 
        }
        
        try {
          // 🛡️ الحل الجذري لتخطي حماية الدارت في الـ NFC
          final Map<dynamic, dynamic> rawTagData = (tag as dynamic).data as Map<dynamic, dynamic>;
          List<int>? identifier;
          
          for (var value in rawTagData.values) {
            if (value is Map && value.containsKey('identifier')) {
              var rawId = value['identifier'];
              if (rawId is List) {
                identifier = rawId.map((e) => int.parse(e.toString())).toList();
                break;
              }
            }
          }
          
          String receiverNfcId = (identifier != null) ? identifier.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase() : "";

          if (receiverNfcId.isEmpty) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ فشل في قراءة البطاقة", style: GoogleFonts.cairo()), backgroundColor: Colors.red));
            return;
          }

          if (mounted) showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));

          // 🚀 الاتصال بالباك إند
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token') ?? '';
          
          final response = await http.put(
            Uri.parse('${ApiService.baseUrl}/admin/settle-driver/'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode({"driver_nfc_id": receiverNfcId}), 
          );

          if (mounted && Navigator.canPop(context)) Navigator.pop(context); // إغلاق التحميل

          if (response.statusCode == 200) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ تمت المصافحة وتفريغ العهدة بنجاح!", style: GoogleFonts.cairo()), backgroundColor: Colors.green));
            _loadWalletData(); 
          } else {
            final err = jsonDecode(utf8.decode(response.bodyBytes));
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ ${err['detail'] ?? 'فشل نقل العهدة'}", style: GoogleFonts.cairo()), backgroundColor: Colors.red));
          }
        } catch (e) {
          if (mounted && Navigator.canPop(context)) Navigator.pop(context);
          debugPrint("NFC Transfer Error: $e");
        }
      }
    );
  }

  // ==========================================
  // 🖥️ واجهة المستخدم (UI Build)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text("محفظة العهدة الميدانية", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo.shade900,
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : RefreshIndicator(
              color: Colors.indigo,
              onRefresh: _loadWalletData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 20, vertical: 20), // 🔥 توسيع الهوامش في الويب
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(),
                    const SizedBox(height: 25),
                    
                    Text("الإجراءات السريعة", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900)),
                    const SizedBox(height: 15),
                    _buildActionButtons(),
                    
                    const SizedBox(height: 30),
                    
                    Text("📑 الشيكات الموجودة بحوزتك", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900)),
                    const SizedBox(height: 10),
                    _buildChequesSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade800, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 24),
              const SizedBox(width: 10),
              Text("السيولة النقدية (الكاش) في جيبك", style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 15),
          Text("${_cashBalance.toStringAsFixed(2)} دج", style: GoogleFonts.cairo(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _actionBtn(
            icon: Icons.local_gas_station_rounded, 
            label: "تسجيل مصروف", 
            color: Colors.orange.shade500, 
            shadowColor: Colors.orange.shade200,
            onTap: _showExpenseDialog
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _actionBtn(
            icon: Icons.nfc_rounded, 
            label: "تفريغ العهدة (NFC)", 
            color: Colors.blue.shade600, 
            shadowColor: Colors.blue.shade200,
            onTap: _startNFCTransfer
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({required IconData icon, required String label, required Color color, required Color shadowColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color, 
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: shadowColor, blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 10),
            Text(label, style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildChequesSection() {
    final isDesktop = kIsWeb;

    if (_heldCheques.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, size: 50, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text("لا توجد شيكات حالياً في عهدتك", style: GoogleFonts.cairo(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return isDesktop
      ? GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, 
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 3.5, // لضبط تناسق البطاقة في الويب
          ),
          itemCount: _heldCheques.length,
          itemBuilder: (context, index) {
            final cheque = _heldCheques[index];
            return Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.amber.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.account_balance_rounded, color: Colors.amber.shade700),
                ),
                title: Text("${cheque['amount']} دج", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text("شيك: ${cheque['cheque_number']} - ${cheque['bank_name']}", style: GoogleFonts.cairo(color: Colors.grey.shade600)),
              ),
            );
          },
        )
      : ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _heldCheques.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final cheque = _heldCheques[index];
            return Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.amber.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.account_balance_rounded, color: Colors.amber.shade700),
                ),
                title: Text("${cheque['amount']} دج", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text("شيك: ${cheque['cheque_number']} - ${cheque['bank_name']}", style: GoogleFonts.cairo(color: Colors.grey.shade600)),
              ),
            );
          },
        );
  }
}