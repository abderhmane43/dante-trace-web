import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد مهم لفحص بيئة الويب
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // 🔥 استيراد مكتبة التنسيق المحاسبي

// 🔗 تأكد من مسار خدمة الـ API الخاص بك
import '../../services/api_service.dart';

class AdminExpenseReviewScreen extends StatefulWidget {
  const AdminExpenseReviewScreen({super.key});

  @override
  State<AdminExpenseReviewScreen> createState() => _AdminExpenseReviewScreenState();
}

class _AdminExpenseReviewScreenState extends State<AdminExpenseReviewScreen> {
  // 🎨 الألوان المؤسسية
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B);
  final Color softBg = const Color(0xFFF8FAFC);
  final Color successGreen = const Color(0xFF2E7D32);
  final Color warningOrange = const Color(0xFFEF6C00);

  bool _isLoading = true;
  List<dynamic> _pendingExpenses = [];

  @override
  void initState() {
    super.initState();
    _fetchPendingExpenses();
  }

  // 📡 1. جلب المصاريف المعلقة
  Future<void> _fetchPendingExpenses() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token') ?? '');
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/expenses/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _pendingExpenses = jsonDecode(utf8.decode(response.bodyBytes));
            _isLoading = false;
          });
        }
      } else {
        _showSnackBar("فشل في جلب البيانات", Colors.red.shade800);
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar("تعذر الاتصال بالخادم", Colors.red.shade800);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ⚙️ 2. نافذة قرار المدير (Bottom Sheet)
  void _showActionDialog(int expenseId, String driverName, double amount, String action) {
    final TextEditingController noteController = TextEditingController();
    final bool isApprove = action == 'approve';
    bool isProcessing = false;
    
    // تنسيق المبلغ للنافذة المنبثقة
    final String formattedAmount = NumberFormat('#,##0.00').format(amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 🔥 جعلناها شفافة لعمل إطار متمركز في الويب
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Center(
              // 🔥 تحديد عرض النافذة بـ 500 بكسل لكي تبدو أنيقة في الحاسوب ولا تتمدد
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
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
                          Icon(isApprove ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isApprove ? successGreen : primaryRed, size: 28),
                          const SizedBox(width: 10),
                          Text(isApprove ? "تأكيد الموافقة على المصروف" : "رفض المصروف", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isApprove 
                            ? "سيتم خصم مبلغ ($formattedAmount دج) من عهدة السائق ($driverName) بشكل نهائي." 
                            : "لن يتم خصم أي مبلغ من السائق ($driverName). يرجى كتابة سبب الرفض.",
                        style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        style: GoogleFonts.cairo(),
                        decoration: InputDecoration(
                          labelText: "ملاحظة الإدارة (اختياري للموافقة، إجباري للرفض)",
                          labelStyle: GoogleFonts.cairo(color: Colors.grey.shade500, fontSize: 13),
                          filled: true,
                          fillColor: softBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isApprove ? successGreen : primaryRed)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isApprove ? successGreen : primaryRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isProcessing ? null : () async {
                            if (!isApprove && noteController.text.trim().isEmpty) {
                              _showSnackBar("يجب كتابة سبب الرفض!", Colors.orange.shade800);
                              return;
                            }
                            setModalState(() => isProcessing = true);
                            await _submitReview(expenseId, action, noteController.text.trim());
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: isProcessing 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text("تأكيد العملية", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  // 📡 3. إرسال القرار للسيرفر
  Future<void> _submitReview(int expenseId, String action, String note) async {
    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token') ?? '');
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/admin/expenses/$expenseId/review'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({"action": action, "admin_note": note}),
      );

      if (response.statusCode == 200) {
        _showSnackBar(action == 'approve' ? "تمت الموافقة وخصم المبلغ بنجاح ✅" : "تم رفض المصروف ❌", action == 'approve' ? successGreen : primaryRed);
        _fetchPendingExpenses(); // تحديث القائمة لإخفاء العنصر المعالج
      } else {
        _showSnackBar("حدث خطأ أثناء معالجة الطلب", Colors.red.shade800);
      }
    } catch (e) {
      _showSnackBar("خطأ في الاتصال بالخادم", Colors.red.shade800);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb; // 🔥 متغير لفحص الويب

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: Text("الرقابة المالية والمصاريف", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkBlue),
        // 🔥 إخفاء القائمة العلوية في الحاسوب
        leading: isDesktop ? const SizedBox.shrink() : null,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPendingExpenses,
        color: primaryRed,
        child: _isLoading 
            ? Center(child: CircularProgressIndicator(color: primaryRed))
            : _pendingExpenses.isEmpty 
                ? _buildEmptyState()
                : isDesktop 
                    // 🔥 عرض الشبكة المتجاوبة للحاسوب
                    ? GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, // عرض بطاقتين أو 3 حسب ما تراه مناسباً لحجم شاشتك
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 1.5, // لضبط ارتفاع البطاقة
                        ),
                        itemCount: _pendingExpenses.length,
                        itemBuilder: (context, index) {
                          return _buildExpenseCard(_pendingExpenses[index], isDesktop);
                        },
                      )
                    // 🔥 عرض القائمة العادية للهاتف
                    : ListView.builder(
                        padding: const EdgeInsets.all(15),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _pendingExpenses.length,
                        itemBuilder: (context, index) {
                          return _buildExpenseCard(_pendingExpenses[index], isDesktop);
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
          Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green.shade300),
          const SizedBox(height: 15),
          Text("الخزينة نظيفة!", style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: darkBlue)),
          Text("لا توجد طلبات مصاريف معلقة للمراجعة", style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> exp, bool isDesktop) {
    // 🛡️ التحويل الآمن والتنسيق المالي
    final double driverBalance = double.tryParse(exp['driver_balance']?.toString() ?? '0') ?? 0.0;
    final double requestedAmount = double.tryParse(exp['amount']?.toString() ?? '0') ?? 0.0;
    
    final String formattedRequested = NumberFormat('#,##0.00').format(requestedAmount);
    final String formattedBalance = NumberFormat('#,##0.00').format(driverBalance);
    
    // جلب التاريخ وتنسيقه إن وجد
    String dateStr = exp['date'] != null ? exp['date'].toString().split('T')[0] : "تاريخ غير محدد";

    // تنبيه إذا كان المصروف أكبر من العهدة الموجودة مع السائق
    final bool isWarning = requestedAmount > driverBalance;

    return Container(
      // 🔥 تصفير الهامش السفلي في الويب لأن الـ GridView يتكفل بالمسافات
      margin: EdgeInsets.only(bottom: isDesktop ? 0 : 15),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: isWarning ? Colors.red.shade200 : Colors.grey.shade200, width: isWarning ? 1.5 : 1), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))]
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: Colors.blue.shade50, child: Icon(Icons.person_rounded, color: Colors.blue.shade700)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(exp['driver_name']?.toString() ?? "سائق", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue), overflow: TextOverflow.ellipsis),
                            Text("طالب مصروف • $dateStr", style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade500, height: 1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Text("$formattedRequested دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17, color: primaryRed)),
              ],
            ),
            const Divider(height: 25),
            Text("البيان:", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade500)),
            
            // 🔥 استخدام Expanded لمنع تجاوز النص للمساحة في الشاشات المختلفة
            Expanded(
              child: SingleChildScrollView(
                child: Text(exp['description']?.toString() ?? "بدون بيان", style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600, color: darkBlue)),
              ),
            ),
            
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: isWarning ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isWarning ? Icons.warning_rounded : Icons.account_balance_wallet_rounded, size: 16, color: isWarning ? primaryRed : successGreen),
                  const SizedBox(width: 6),
                  Text("رصيد العهدة الحالي: $formattedBalance دج", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: isWarning ? primaryRed : successGreen)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: primaryRed, side: BorderSide(color: primaryRed.withOpacity(0.5)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: Text("رفض", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    onPressed: () => _showActionDialog(exp['expense_id'], exp['driver_name'], requestedAmount, 'reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: successGreen, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: Text("موافقة وخصم", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    onPressed: () => _showActionDialog(exp['expense_id'], exp['driver_name'], requestedAmount, 'approve'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}