import 'dart:async'; 
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection; 
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class VerifyPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback onSuccess;

  const VerifyPaymentDialog({
    super.key,
    required this.order,
    required this.onSuccess,
  });

  @override
  State<VerifyPaymentDialog> createState() => _VerifyPaymentDialogState();
}

class _VerifyPaymentDialogState extends State<VerifyPaymentDialog> {
  bool _isProcessing = false;
  bool _isLoadingDetails = true;
  String _paymentDetails = "";
  
  double _parsedCash = 0.0;
  double _parsedCheck = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchPaymentDetails();
  }

  Future<void> _fetchPaymentDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/orders/${widget.order['id']}/history'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        List<dynamic> history = jsonDecode(utf8.decode(response.bodyBytes));
        
        var declaration = history.reversed.firstWhere(
          (h) => h['action'] == 'تصريح بالدفع من الزبون', 
          orElse: () => null
        );

        if (declaration != null && mounted) {
          setState(() {
            String rawNotes = declaration['notes'] ?? '';
            if(rawNotes.contains('-> التفاصيل:')) {
                String details = rawNotes.split('-> التفاصيل:').last.trim();
                
                RegExp cashReg = RegExp(r'cash:\s*([\d\.]+)');
                RegExp checkReg = RegExp(r'cheque:\s*([\d\.]+)');
                
                var cMatch = cashReg.firstMatch(details);
                if (cMatch != null) _parsedCash = double.tryParse(cMatch.group(1)!) ?? 0.0;
                
                var chMatch = checkReg.firstMatch(details);
                if (chMatch != null) _parsedCheck = double.tryParse(chMatch.group(1)!) ?? 0.0;

                details = details.replaceAll('cash', '💵 نقداً (كاش)');
                details = details.replaceAll('cheque', '📄 شيك بنكي');
                details = details.replaceAll('debt', '📝 دين (بالآجل)');
                details = details.replaceAll('مرجع: لا يوجد', 'بدون مرجع');
                details = details.replaceAll(' | ', '\n');
                _paymentDetails = details;
            } else {
                _paymentDetails = rawNotes;
            }
            _isLoadingDetails = false;
          });
        } else {
           setState(() {
            _paymentDetails = "لم يتم العثور على تفاصيل مفصلة.";
            _isLoadingDetails = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _paymentDetails = "تعذر جلب التفاصيل. تأكد من اتصالك.";
          _isLoadingDetails = false;
        });
      }
    }
  }

  Future<void> _submitVerification() async {
    setState(() => _isProcessing = true);
    
    // 🔥 الإصلاح الجذري: إرسال المبالغ مفصولة للسيرفر بناءً على ما صرح به الزبون
    // في حال فشل استخراج القيم، سنرسل المبلغ الإجمالي ككاش مؤقتاً كخطة بديلة (Fallback)
    double totalAmount = double.tryParse(widget.order['cash_amount']?.toString() ?? '0') ?? 0.0;
    
    double finalCash = _parsedCash;
    double finalCheck = _parsedCheck;
    
    if (finalCash == 0 && finalCheck == 0) {
      finalCash = totalAmount; // Fallback
    }
    
    // إرسال القيم المفصولة للسيرفر لكي يحسبها في العهدة بشكل صحيح
    bool success = await ApiService.adminVerifyPayment(widget.order['id'], finalCash, finalCheck);
    
    if (!mounted) return;
    Navigator.pop(context); 
    
    if (success) {
      widget.onSuccess(); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ حدث خطأ أثناء المراجعة. حاول لاحقاً.", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)), backgroundColor: Colors.red)
      );
    }
  }

  // 🔥 دالة الرفض مع نافذة لإدخال السبب
  void _rejectDeclaration() {
    TextEditingController reasonCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text("رفض تصريح الدفع", style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: "اذكر السبب (مثال: مبلغ الكاش المدخل غير صحيح)",
            hintStyle: GoogleFonts.cairo(fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx); // إغلاق نافذة السبب
              setState(() => _isProcessing = true);
              
              bool success = await ApiService.adminRejectPayment(widget.order['id'], reasonCtrl.text.trim());
              
              if (!mounted) return;
              Navigator.pop(context); // إغلاق النافذة الرئيسية
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("تم الرفض بنجاح وإرجاع الطلبية للزبون", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange.shade800)
                );
                widget.onSuccess(); 
              } else {
                setState(() => _isProcessing = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("❌ فشل الاتصال بالسيرفر", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)), backgroundColor: Colors.red)
                );
              }
            },
            child: Text("تأكيد الرفض", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: Colors.green),
          const SizedBox(width: 10),
          Text("مراجعة وتأكيد الدفع", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("الزبون (${order['customer_name']}) صرّح بأنه قام بتسديد مبلغ:", style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 10),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text(
                  "${NumberFormat('#,##0.00').format(double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0)} دج", 
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green.shade800)
                ),
              ),
            ),
            
            const SizedBox(height: 15),
            Text("تفاصيل الدفع المصرح بها:", style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50, 
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200)
              ),
              child: _isLoadingDetails 
                ? const Center(child: Padding(padding: EdgeInsets.all(10.0), child: CircularProgressIndicator(strokeWidth: 2)))
                : Text(
                    _paymentDetails, 
                    style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B), height: 1.8),
                    textDirection: TextDirection.rtl,
                  ),
            ),

            const SizedBox(height: 15),
            Text("تأكيد سيحول المبالغ المذكورة لعهدة السائق. الرفض سيعيد الطلبية للزبون ليصرح مجدداً.", style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade600, height: 1.4)),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 🔥 زر الرفض
            TextButton.icon(
              onPressed: _isProcessing ? null : _rejectDeclaration, 
              icon: const Icon(Icons.close, color: Colors.red, size: 18),
              label: Text("رفض وتصحيح", style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))
            ),
            // 🔥 زر القبول
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: _isProcessing 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check, color: Colors.white, size: 16),
              label: Text("تأكيد وحفظ", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: _isProcessing ? null : _submitVerification,
            )
          ],
        )
      ],
    );
  }
}