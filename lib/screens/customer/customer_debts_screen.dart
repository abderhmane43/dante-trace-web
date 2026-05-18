import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../services/api_service.dart';

class CustomerDebtsScreen extends StatefulWidget {
  const CustomerDebtsScreen({super.key});

  @override
  State<CustomerDebtsScreen> createState() => _CustomerDebtsScreenState();
}

class _CustomerDebtsScreenState extends State<CustomerDebtsScreen> {
  Map<String, dynamic>? debtData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    setState(() => isLoading = true);
    final data = await ApiService.getCustomerDebts();
    if (mounted) {
      setState(() {
        debtData = data;
        isLoading = false;
      });
    }
  }

  // 🔥 دالة لعرض صورة الشيك للزبون
  void _showImageDialog(String base64String) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("صورة الشيك المرفق", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              child: Image.memory(base64Decode(base64String), fit: BoxFit.contain),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("سجل الديون (الآجل)", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.red.shade900),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // بطاقة إجمالي الدين
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.red.shade200),
                    boxShadow: [BoxShadow(color: Colors.red.shade100.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))]
                  ),
                  child: Column(
                    children: [
                      Text("إجمالي الديون المتبقية بذمتك", style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                      const SizedBox(height: 10),
                      Text("${NumberFormat('#,##0.00').format(double.tryParse(debtData?['total_debt']?.toString() ?? '0') ?? 0)} دج", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                    ],
                  ),
                ),
                Expanded(
                  child: (debtData?['debts'] as List).isEmpty
                      ? Center(child: Text("ليس لديك أي ديون مسجلة 🎉", style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey)))
                      : ListView.builder(
                          itemCount: debtData!['debts'].length,
                          itemBuilder: (context, index) {
                            final debt = debtData!['debts'][index];
                            
                            bool isPending = debt['status'] == 'pending_debt_verification';
                            String checkFile = debt['customer_check_file'] ?? '';

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("طرد رقم: ${debt['tracking_number']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isPending ? Colors.orange.shade50 : Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: isPending ? Colors.orange.shade200 : Colors.red.shade200)
                                          ),
                                          child: Text(
                                            isPending ? "بانتظار تأكيد الإدارة ⏳" : "دين معلق ⚠️",
                                            style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: isPending ? Colors.orange.shade800 : Colors.red.shade800)
                                          ),
                                        )
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("المبلغ الإجمالي:", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade700)),
                                        Text("${NumberFormat('#,##0.00').format(double.tryParse(debt['total_amount']?.toString() ?? '0') ?? 0)} دج", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("المدفوع والمؤكد:", style: GoogleFonts.cairo(fontSize: 12, color: Colors.green.shade700)),
                                        Text("${NumberFormat('#,##0.00').format(double.tryParse(debt['paid_amount']?.toString() ?? '0') ?? 0)} دج", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("الباقي (للدفع):", style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                                        Text("${NumberFormat('#,##0.00').format(double.tryParse(debt['remaining_amount']?.toString() ?? '0') ?? 0)} دج", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                                      ],
                                    ),
                                    
                                    // 🔥 زر مشاهدة الشيك المرفق إذا وجد
                                    if (checkFile.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _showImageDialog(checkFile),
                                          icon: const Icon(Icons.image, size: 16),
                                          label: Text("مشاهدة الشيك المرفق للإدارة", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade50, foregroundColor: Colors.purple.shade800, elevation: 0),
                                        ),
                                      )
                                    ],

                                    if (debt['status'] == 'unpaid_debt') ...[
                                      const SizedBox(height: 15),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            // TODO: استدعاء دالة فتح الشيت السفلية الخاصة بالدفع الموجودة في CustomerDashboardScreen
                                            // يمكنك توجيه المستخدم للوحة الرئيسية لكي يقوم بالدفع من هناك
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("للشروع في الدفع، يرجى العودة للوحة الرئيسية والضغط على (تسديد الدين) للطرد المطلوب.", style: GoogleFonts.cairo())));
                                          },
                                          icon: const Icon(Icons.payment, size: 18),
                                          label: Text("تسديد جزء من الدين", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                                        ),
                                      )
                                    ]
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}