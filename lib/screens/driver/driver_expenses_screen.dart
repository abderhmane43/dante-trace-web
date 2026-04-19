import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // 🔥 استيراد التنسيق المالي

import '../../services/api_service.dart';

class DriverExpensesScreen extends StatefulWidget {
  const DriverExpensesScreen({super.key});

  @override
  State<DriverExpensesScreen> createState() => _DriverExpensesScreenState();
}

class _DriverExpensesScreenState extends State<DriverExpensesScreen> {
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B);
  final Color softBg = const Color(0xFFF8FAFC);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  bool _isSubmitting = false;

  // قائمة المصاريف الشائعة لتسهيل الكتابة على السائق
  final List<String> _commonExpenses = [
    "تعبئة وقود (بنزين/مازوت)",
    "غسيل الشاحنة",
    "صيانة خفيفة / بنشر",
    "رسوم طريق / مواقف",
    "إطعام (في مهمة طويلة)"
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _addCommonExpense(String expense) {
    setState(() {
      _descCtrl.text = expense;
    });
  }

  Future<void> _submitExpense() async {
    if (_isSubmitting) return; // منع الإرسال المزدوج
    if (!_formKey.currentState!.validate()) return;

    // استخراج المبلغ وتأمينه ضد المسافات والفواصل الخاطئة
    final String amountText = _amountCtrl.text.replaceAll(',', '.').replaceAll(' ', '').trim();
    final double amount = double.tryParse(amountText) ?? 0.0;

    if (amount <= 0) {
      _showToast("يرجى إدخال مبلغ صحيح أكبر من الصفر", Colors.red);
      return;
    }

    // 🔥 تنسيق المبلغ للعرض في رسالة التأكيد
    final String formattedAmount = NumberFormat('#,##0.00').format(amount);
    final String description = _descCtrl.text.trim();

    // إظهار نافذة تأكيد قبل الإرسال للإدارة
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Text("تأكيد طلب المصروف", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: "هل أنت متأكد من إرسال طلب تعويض بقيمة\n", style: GoogleFonts.cairo(fontSize: 14)),
              TextSpan(text: "$formattedAmount دج\n", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: primaryRed)),
              TextSpan(text: "لغرض: $description؟", style: GoogleFonts.cairo(fontSize: 14)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("تعديل", style: GoogleFonts.cairo(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: darkBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("نعم، إرسال للإدارة", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isSubmitting = true);

    bool success = await ApiService.submitDriverExpense(amount, description);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      _amountCtrl.clear();
      _descCtrl.clear();
      _showToast("✅ تم إرسال الطلب للإدارة بنجاح وسيتم تعويضك لاحقاً", Colors.green.shade700);
      FocusScope.of(context).unfocus(); // إغلاق لوحة المفاتيح
    } else {
      _showToast("❌ تعذر إرسال الطلب، يرجى المحاولة لاحقاً", Colors.red);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: Text("تسجيل المصاريف", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: darkBlue,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ℹ️ بطاقة معلومات
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.blue.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "أدخل المبالغ التي صرفتها من مالك الخاص أو من العهدة لتغطية مصاريف الشاحنة أو العمل. ستتم مراجعة الطلب من قبل الإدارة وإضافته لرصيدك.",
                          style: GoogleFonts.cairo(fontSize: 12, color: Colors.blue.shade900, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // 💰 حقل المبلغ
                Text("المبلغ المدفوع (دج)", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 15)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: primaryRed),
                  decoration: InputDecoration(
                    hintText: "0.00",
                    hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Icon(Icons.payments_outlined, color: primaryRed, size: 28),
                    ),
                    suffixText: "DZD",
                    suffixStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryRed, width: 2)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "يرجى إدخال المبلغ";
                    if (double.tryParse(val.replaceAll(',', '.').replaceAll(' ', '')) == null) return "تنسيق المبلغ غير صحيح";
                    return null;
                  },
                ),
                const SizedBox(height: 25),

                // 📝 حقل الوصف
                Text("وصف المصروف", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 15)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  style: GoogleFonts.cairo(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "مثال: تعبئة وقود مازوت من محطة وسط المدينة...",
                    hintStyle: GoogleFonts.cairo(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: darkBlue, width: 2)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "يرجى كتابة سبب أو وصف المصروف";
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // 🏷️ اقتراحات سريعة
                Text("اقتراحات سريعة:", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonExpenses.map((exp) {
                    return InkWell(
                      onTap: () => _addCommonExpense(exp),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(exp, style: GoogleFonts.cairo(fontSize: 12, color: darkBlue)),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 50),

                // 🚀 زر الإرسال
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitExpense,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    icon: _isSubmitting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _isSubmitting ? "جاري الإرسال..." : "تقديم طلب التعويض", 
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}