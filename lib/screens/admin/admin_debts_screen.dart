import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../services/api_service.dart';

class AdminDebtsScreen extends StatefulWidget {
  const AdminDebtsScreen({super.key});

  @override
  State<AdminDebtsScreen> createState() => _AdminDebtsScreenState();
}

class _AdminDebtsScreenState extends State<AdminDebtsScreen> {
  List<dynamic> customersDebts = [];
  List<dynamic> activeDrivers = []; 
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => isLoading = true);
    final debtsData = await ApiService.getAllDebtsAdmin();
    final driversData = await ApiService.getActiveDrivers(); 
    if (mounted) {
      setState(() {
        customersDebts = debtsData;
        activeDrivers = driversData;
        isLoading = false;
      });
    }
  }

  // 🔥 نافذة لعرض صورة الشيك
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

  // 🔥 نافذة الرفض المنبثقة
  void _showRejectDialog(Map<String, dynamic> shipment) {
    TextEditingController reasonController = TextEditingController();
    bool isRejecting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Text("رفض الدفعة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade900)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("يرجى كتابة سبب رفض هذه الدفعة لكي يتمكن الزبون من تصحيحها وإعادة الإرسال:", style: GoogleFonts.cairo(fontSize: 13)),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "مثال: صورة الشيك غير واضحة، أو المبلغ خاطئ...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: Colors.red.shade50
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isRejecting ? null : () => Navigator.pop(context), 
              child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: isRejecting ? null : () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("يرجى كتابة سبب الرفض!", style: GoogleFonts.cairo()), backgroundColor: Colors.orange));
                  return;
                }

                setDialogState(() => isRejecting = true);

                bool success = await ApiService.adminRejectDebt(shipment['id'], reasonController.text.trim());
                
                if (!mounted) return;
                
                if (success) {
                  Navigator.pop(context); // إغلاق نافذة الرفض
                  Navigator.pop(context); // إغلاق نافذة المراجعة الرئيسية
                  _loadInitialData(); // تحديث الشاشة
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ تم الرفض وإشعار الزبون!", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)), backgroundColor: Colors.green.shade700));
                } else {
                  setDialogState(() => isRejecting = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ حدث خطأ أثناء الرفض", style: GoogleFonts.cairo()), backgroundColor: Colors.red));
                }
              },
              child: isRejecting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text("تأكيد الرفض", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        )
      ),
    );
  }

  void _showVerifyDebtDialog(Map<String, dynamic> shipment) {
    double declaredCash = 0.0;
    double declaredCheck = 0.0;
    
    if (shipment['payments_history'] != null && (shipment['payments_history'] as List).isNotEmpty) {
      var lastRecord = (shipment['payments_history'] as List).last;
      if (lastRecord['amount'] != null) {
         declaredCash = double.tryParse(lastRecord['amount'].toString()) ?? 0.0;
      }
    }

    TextEditingController cashController = TextEditingController(text: declaredCash > 0 ? declaredCash.toStringAsFixed(0) : "");
    TextEditingController checkController = TextEditingController(text: declaredCheck > 0 ? declaredCheck.toStringAsFixed(0) : "");
    
    bool isSubmitting = false;
    bool paidToAdmin = true; 
    int? selectedDriverId;
    
    if (activeDrivers.isNotEmpty) {
      selectedDriverId = activeDrivers[0]['id'];
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text("مراجعة دفعة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    "الدين المتبقي: ${NumberFormat('#,##0.00').format(double.tryParse(shipment['remaining_amount']?.toString() ?? '0') ?? 0)} دج", 
                    style: GoogleFonts.poppins(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 13)
                  ),
                ),
                const SizedBox(height: 15),

                // 🔥 عرض تفاصيل الشيك المرفق إذا وجد
                if (shipment['customer_check_number'] != null || shipment['customer_check_file'] != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.purple.shade50, border: Border.all(color: Colors.purple.shade100), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("📌 معلومات الشيك المرفق:", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.purple.shade900, fontSize: 12)),
                        const SizedBox(height: 5),
                        Text("رقم الشيك: ${shipment['customer_check_number'] ?? 'غير متوفر'}", style: GoogleFonts.cairo(fontSize: 12)),
                        Text("صاحب الشيك: ${shipment['customer_check_owner'] ?? 'غير متوفر'}", style: GoogleFonts.cairo(fontSize: 12)),
                        if (shipment['customer_check_file'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: ElevatedButton.icon(
                              // 🔥 تم حل مشكلة String? بإضافة .toString()
                              onPressed: () => _showImageDialog(shipment['customer_check_file'].toString()), 
                              icon: const Icon(Icons.image, size: 16),
                              label: Text("مشاهدة صورة الشيك", style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white, elevation: 0),
                            ),
                          )
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
                
                Text("المبلغ الذي استلمته نقداً (كاش):", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade800)),
                const SizedBox(height: 5),
                TextField(
                  controller: cashController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "أدخل الكاش...",
                    prefixIcon: const Icon(Icons.money, color: Colors.green),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true, fillColor: Colors.green.shade50
                  ),
                ),
                const SizedBox(height: 15),
                
                Text("المبلغ الذي استلمته بصك (شيك):", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple.shade800)),
                const SizedBox(height: 5),
                TextField(
                  controller: checkController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "أدخل الشيك...",
                    prefixIcon: const Icon(Icons.receipt, color: Colors.purple),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true, fillColor: Colors.purple.shade50
                  ),
                ),
                const SizedBox(height: 15),
                const Divider(),
                
                Text("من الذي استلم هذا المبلغ فعلياً؟", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                CheckboxListTile(
                  title: Text("استلمته أنا (دخل خزينة الإدارة مباشرة)", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                  value: paidToAdmin,
                  activeColor: Colors.blue.shade900,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (val) {
                    setDialogState(() {
                      paidToAdmin = val ?? true;
                    });
                  },
                ),
                if (!paidToAdmin && activeDrivers.isNotEmpty) ...[
                  Text("اختر السائق الذي استلم الدفعة:", style: GoogleFonts.cairo(fontSize: 12)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedDriverId,
                        isExpanded: true,
                        items: activeDrivers.map((d) {
                          return DropdownMenuItem<int>(
                            value: d['id'],
                            child: Text(d['name'], style: GoogleFonts.cairo(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedDriverId = val;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            // 🔥 زر الرفض
            TextButton.icon(
              onPressed: isSubmitting ? null : () => _showRejectDialog(shipment),
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: Text("رفض", style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            
            // 🔥 زر التأكيد
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: isSubmitting ? null : () async {
                double approvedCash = double.tryParse(cashController.text) ?? 0.0;
                double approvedCheck = double.tryParse(checkController.text) ?? 0.0;
                
                if (approvedCash <= 0 && approvedCheck <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("يرجى إدخال مبلغ صحيح!", style: GoogleFonts.cairo()), backgroundColor: Colors.orange));
                  return;
                }
                
                if (!paidToAdmin && selectedDriverId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("يرجى اختيار السائق!", style: GoogleFonts.cairo()), backgroundColor: Colors.red));
                  return;
                }
                
                setDialogState(() => isSubmitting = true);
                
                bool success = await ApiService.adminVerifyDebt(
                  shipment['id'], 
                  approvedCash,
                  approvedCheck: approvedCheck,
                  paidToAdminDirectly: paidToAdmin,
                  actualDriverId: paidToAdmin ? null : selectedDriverId,
                );
                
                if (!mounted) return;
                
                if (success) {
                  Navigator.pop(context);
                  _loadInitialData(); // تحديث الشاشة
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ تم تأكيد الدفعة بنجاح!", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)), backgroundColor: Colors.green.shade700));
                } else {
                  setDialogState(() => isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ حدث خطأ أثناء التأكيد", style: GoogleFonts.cairo()), backgroundColor: Colors.red));
                }
              },
              icon: isSubmitting 
                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle, color: Colors.white, size: 18),
              label: Text("تأكيد وحفظ", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        )
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("مراقبة ديون السوق (الآجل)", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.red.shade900),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : customersDebts.isEmpty 
              ? Center(child: Text("لا توجد ديون في السوق حالياً 🎉", style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: customersDebts.length,
                  itemBuilder: (context, index) {
                    final customer = customersDebts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: CircleAvatar(backgroundColor: Colors.red.shade50, child: Icon(Icons.person, color: Colors.red.shade800)),
                          title: Text(customer['customer_name'] ?? 'زبون', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
                          subtitle: Text("إجمالي ديونه: ${NumberFormat('#,##0.00').format(double.tryParse(customer['total_remaining']?.toString() ?? '0') ?? 0)} دج", style: GoogleFonts.poppins(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                          children: (customer['shipments'] as List).map((shipment) {
                            
                            List<dynamic> paymentsHistory = shipment['payments_history'] ?? [];
                            
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("طرد: ${shipment['tracking_number']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                                      if (shipment['status'] == 'pending_debt_verification' || shipment['payment_status'] == 'pending_debt_verification')
                                        ElevatedButton(
                                          onPressed: () => _showVerifyDebtDialog(shipment),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                          child: Text("مراجعة الدفعة", style: GoogleFonts.cairo(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                        )
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text("الدين المتبقي: ${NumberFormat('#,##0.00').format(double.tryParse(shipment['remaining_amount']?.toString() ?? '0') ?? 0)} دج", style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.bold)),
                                  
                                  if (paymentsHistory.isNotEmpty) ...[
                                    const Divider(height: 20),
                                    Text("سجل الدفعات السابقة / الحالية:", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                    const SizedBox(height: 5),
                                    ...paymentsHistory.map((pay) {
                                      bool inDriverCustody = pay['status'] == 'in_driver_custody' || pay['status'] == 'pending_settlement';
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4.0),
                                        child: Row(
                                          children: [
                                            Icon(inDriverCustody ? Icons.hail_rounded : Icons.account_balance_rounded, size: 14, color: inDriverCustody ? Colors.orange : Colors.green),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                "دفعة مسجلة: ${NumberFormat('#,##0').format(double.tryParse(pay['amount']?.toString() ?? '0') ?? 0)} دج (${pay['receiver_name'] ?? 'السائق'})", 
                                                style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade800)
                                              )
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: inDriverCustody ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(5)),
                                              child: Text(inDriverCustody ? "بعهدة السائق" : "وصلت الخزينة", style: GoogleFonts.cairo(fontSize: 9, fontWeight: FontWeight.bold, color: inDriverCustody ? Colors.orange.shade800 : Colors.green.shade800)),
                                            )
                                          ],
                                        ),
                                      );
                                    })
                                  ]
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}