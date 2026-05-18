import 'dart:async'; 
import 'dart:convert';
import 'dart:io' as io; 
import 'dart:typed_data'; 
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection; 
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:open_filex/open_filex.dart'; 
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
  String _rawCustomerNotes = "";
  
  // ما صرح به الزبون
  double _declaredCash = 0.0;
  double _declaredCheck = 0.0;
  double _declaredDebt = 0.0; 

  // ما سيعتمده المدير
  final TextEditingController _adminCashCtrl = TextEditingController();
  final TextEditingController _adminCheckCtrl = TextEditingController();
  final TextEditingController _adminDebtCtrl = TextEditingController();

  double _totalRequired = 0.0;

  @override
  void initState() {
    super.initState();
    _totalRequired = double.tryParse(widget.order['cash_amount']?.toString() ?? '0') ?? 0.0;
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
          (h) => h['action'] == 'تصريح بالدفع', 
          orElse: () => null
        );

        if (declaration != null && mounted) {
          String rawNotes = declaration['notes'] ?? '';
          _rawCustomerNotes = rawNotes;

          if (rawNotes.contains('-> التفاصيل:')) {
            String details = rawNotes.split('-> التفاصيل:').last.trim();
            
            // 🔥 الحل الذكي: تعبيرات منتظمة تقرأ العربية والإنجليزية بمرونة
            RegExp cashReg = RegExp(r'(?:cash|كاش|نقدا|نقداً).*?([0-9]*\.?[0-9]+)', caseSensitive: false);
            RegExp checkReg = RegExp(r'(?:cheque|check|شيك|صك).*?([0-9]*\.?[0-9]+)', caseSensitive: false);
            RegExp debtReg = RegExp(r'(?:debt|دين|آجل).*?([0-9]*\.?[0-9]+)', caseSensitive: false); 
            
            var cMatch = cashReg.firstMatch(details);
            if (cMatch != null) _declaredCash = double.tryParse(cMatch.group(1)!) ?? 0.0;
            
            var chMatch = checkReg.firstMatch(details);
            if (chMatch != null) _declaredCheck = double.tryParse(chMatch.group(1)!) ?? 0.0;

            var dMatch = debtReg.firstMatch(details);
            if (dMatch != null) _declaredDebt = double.tryParse(dMatch.group(1)!) ?? 0.0;
          } else {
            // إذا لم يجد تفاصيل دقيقة، يضع المبلغ الكلي في الكاش لتتأكد منه يدوياً
            _declaredCash = _totalRequired;
          }
        } else {
          _rawCustomerNotes = "لم يتم العثور على تصريح مفصل.";
        }

        // 🔥 ملء حقول الإدارة تلقائياً بما قاله الزبون لتسهيل العمل دون أخطاء
        if (mounted) {
          setState(() {
            _adminCashCtrl.text = _declaredCash > 0 ? _declaredCash.toStringAsFixed(0) : "";
            _adminCheckCtrl.text = _declaredCheck > 0 ? _declaredCheck.toStringAsFixed(0) : "";
            _adminDebtCtrl.text = _declaredDebt > 0 ? _declaredDebt.toStringAsFixed(0) : "";
            _isLoadingDetails = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rawCustomerNotes = "تعذر جلب التفاصيل. يرجى إدخال المبالغ يدوياً.";
          _isLoadingDetails = false;
        });
      }
    }
  }

  void _recalculate(void Function(void Function()) setModalState) {
    setModalState(() {}); // فقط لإنعاش واجهة الحسابات
  }

  Future<void> _submitVerification() async {
    double adminCash = double.tryParse(_adminCashCtrl.text) ?? 0.0;
    double adminCheck = double.tryParse(_adminCheckCtrl.text) ?? 0.0;
    double adminDebt = double.tryParse(_adminDebtCtrl.text) ?? 0.0;
    
    double currentTotal = adminCash + adminCheck + adminDebt;
    if ((currentTotal - _totalRequired).abs() > 1.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("المجموع لا يطابق السعر الكلي للطرد!", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange.shade800)
      );
      return;
    }

    setState(() => _isProcessing = true);
    
    bool success = await ApiService.adminVerifyPayment(widget.order['id'], adminCash, adminCheck, adminDebt);
    
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
              Navigator.pop(ctx); 
              setState(() => _isProcessing = true);
              
              bool success = await ApiService.adminRejectPayment(widget.order['id'], reasonCtrl.text.trim());
              
              if (!mounted) return;
              Navigator.pop(context); 
              
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

  Future<void> _openPdfFile(String base64String) async {
    try {
      if (kIsWeb) {
        final uri = Uri.parse('data:application/pdf;base64,$base64String');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } else {
        Uint8List bytes = base64Decode(base64String);
        final dir = await getApplicationDocumentsDirectory();
        final file = io.File('${dir.path}/Dante_Invoice_${widget.order['id']}.pdf');
        await file.writeAsBytes(bytes, flush: true);
        
        final result = await OpenFilex.open(file.path);
        
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ لم نتمكن من فتح الملف. يرجى التأكد من وجود قارئ PDF.", style: GoogleFonts.cairo()), backgroundColor: Colors.red)
          );
        }
      }
    } catch (e) {
      debugPrint("Error handling PDF: $e");
    }
  }

  void _showFilePreview(String base64String, String titleText, Color themeColor) {
    try {
      bool isPdf = base64String.startsWith('JVBER') || base64String.startsWith('JVBE');
      Uint8List bytes = base64Decode(base64String);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          contentPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Icon(Icons.attachment_rounded, color: themeColor),
              const SizedBox(width: 8),
              Expanded(child: Text(titleText, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.5,
            child: isPdf 
              ? Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.red.shade50,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 70),
                      const SizedBox(height: 15),
                      Text("هذا المرفق بصيغة PDF", style: GoogleFonts.cairo(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 10),
                      Text("لا يمكن عرض ملفات PDF كصورة. انقر على الزر أدناه للتحميل.", textAlign: TextAlign.center, style: GoogleFonts.cairo(color: Colors.red.shade900, fontSize: 13)),
                      const SizedBox(height: 25),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx); 
                          _openPdfFile(base64String); 
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700, 
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        icon: const Icon(Icons.download_rounded),
                        label: Text("فتح / تحميل الفاتورة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                      )
                    ],
                  ),
                )
              : InteractiveViewer( 
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Center(child: Text("خطأ في عرض الصورة", style: GoogleFonts.cairo())),
                  ),
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("إغلاق المعاينة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.grey.shade700))
            )
          ],
        )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ تعذر فتح الملف المرفق", style: GoogleFonts.cairo()), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(15),
      title: Row(
        children: [
          const Icon(Icons.shield_rounded, color: Colors.green),
          const SizedBox(width: 10),
          Text("نظام المطابقة المالية", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          
          double adminCash = double.tryParse(_adminCashCtrl.text) ?? 0.0;
          double adminCheck = double.tryParse(_adminCheckCtrl.text) ?? 0.0;
          double adminDebt = double.tryParse(_adminDebtCtrl.text) ?? 0.0;
          double currentTotal = adminCash + adminCheck + adminDebt;
          bool isBalanced = (currentTotal - _totalRequired).abs() < 1.0;

          return SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // 1️⃣ إجمالي الطرد المطلوب
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade200)),
                    child: Column(
                      children: [
                        Text("قيمة الطرد الإجمالية", style: GoogleFonts.cairo(fontSize: 13, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                        Text("${NumberFormat('#,##0.00').format(_totalRequired)} دج", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 2️⃣ تصريح الزبون
                  Text("تصريح الزبون (${order['customer_name']}):", style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 10),

                  _isLoadingDetails 
                    ? const Center(child: Padding(padding: EdgeInsets.all(10.0), child: CircularProgressIndicator(strokeWidth: 2)))
                    : Column(
                        children: [
                          if (_declaredCash > 0)
                            Row(children: [const Icon(Icons.money, color: Colors.green, size: 18), const SizedBox(width: 5), Text("كاش: ${_declaredCash.toStringAsFixed(0)} دج", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.green.shade800))]),
                          if (_declaredCheck > 0)
                            Row(children: [const Icon(Icons.receipt, color: Colors.purple, size: 18), const SizedBox(width: 5), Text("شيك: ${_declaredCheck.toStringAsFixed(0)} دج", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.purple.shade800))]),
                          if (_declaredDebt > 0)
                            Row(children: [const Icon(Icons.edit_note, color: Colors.red, size: 18), const SizedBox(width: 5), Text("دين بالآجل: ${_declaredDebt.toStringAsFixed(0)} دج", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red.shade800))]),
                          
                          if (_declaredCash == 0 && _declaredCheck == 0 && _declaredDebt == 0)
                            Text("لا توجد مبالغ مفصلة", style: GoogleFonts.cairo(color: Colors.grey)),
                        ],
                      ),

                  const Divider(height: 30, thickness: 1),

                  // 3️⃣ إدخال مبالغ التأكيد
                  Text("المبالغ الفعلية المعتمدة (تأكيد الإدارة):", style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 10),

                  // حقل الكاش
                  TextField(
                    controller: _adminCashCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _recalculate(setModalState),
                    decoration: InputDecoration(
                      labelText: "المبلغ نقداً (Cash)",
                      prefixIcon: const Icon(Icons.money, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10)
                    ),
                  ),
                  const SizedBox(height: 10),

                  // حقل الشيك
                  TextField(
                    controller: _adminCheckCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _recalculate(setModalState),
                    decoration: InputDecoration(
                      labelText: "مبلغ الشيك (إن وجد)",
                      prefixIcon: const Icon(Icons.receipt, color: Colors.purple),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10)
                    ),
                  ),
                  const SizedBox(height: 10),

                  // حقل الدين
                  TextField(
                    controller: _adminDebtCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _recalculate(setModalState),
                    decoration: InputDecoration(
                      labelText: "المبلغ كدين (بالآجل)",
                      prefixIcon: const Icon(Icons.edit_note, color: Colors.red),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10)
                    ),
                  ),

                  const SizedBox(height: 15),
                  
                  // الميزان
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: isBalanced ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Icon(isBalanced ? Icons.balance_rounded : Icons.warning_amber_rounded, color: isBalanced ? Colors.green : Colors.orange.shade800, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text("المجموع الذي أدخلته: ${NumberFormat('#,##0').format(currentTotal)} دج", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isBalanced ? Colors.green.shade800 : Colors.orange.shade900))),
                      ],
                    ),
                  ),

                  // مرفقات الشيك
                  if (order['customer_check_owner'] != null && order['customer_check_owner'].toString().trim().isNotEmpty) ...[
                    const Divider(height: 25),
                    Text("صاحب الشيك: ${order['customer_check_owner']}", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 13)),
                  ],

                  if (order['customer_check_file'] != null && order['customer_check_file'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showFilePreview(order['customer_check_file'], "صورة الشيك", Colors.purple),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade50, foregroundColor: Colors.purple.shade800, elevation: 0),
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: Text("عرض صورة الشيك المرفق", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    ),
                  ],

                  if (order['customer_company_file'] != null && order['customer_company_file'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showFilePreview(order['customer_company_file'], "فاتورة الشركة", Colors.red),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade800, elevation: 0),
                      icon: const Icon(Icons.description_rounded),
                      label: Text("عرض الفاتورة / ملف الشركة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    ),
                  ],

                ],
              ),
            ),
          );
        }
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _isProcessing ? null : _rejectDeclaration, 
              icon: const Icon(Icons.close, color: Colors.red, size: 18),
              label: Text("رفض وتصحيح", style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: _isProcessing 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check, color: Colors.white, size: 16),
              label: Text("تأكيد المبالغ", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: _isProcessing ? null : _submitVerification,
            )
          ],
        )
      ],
    );
  }
}