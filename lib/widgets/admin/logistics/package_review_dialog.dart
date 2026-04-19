import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PackageReviewDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final List<dynamic> fleet;
  final Function(String driverId) onManualDispatch;
  final VoidCallback onNfcDispatch;

  const PackageReviewDialog({
    super.key,
    required this.order,
    required this.fleet,
    required this.onManualDispatch,
    required this.onNfcDispatch,
  });

  @override
  State<PackageReviewDialog> createState() => _PackageReviewDialogState();
}

class _PackageReviewDialogState extends State<PackageReviewDialog> {
  String? selectedDriverId;

  @override
  Widget build(BuildContext context) {
    // 🛡️ استخراج آمن للبيانات لمنع الشاشة الحمراء (Crash)
    final String trackingNum = widget.order['tracking_number']?.toString() ?? 'رقم التتبع غير متوفر';
    final String customerName = widget.order['customer_name']?.toString() ?? 'زبون غير معروف';
    final List<dynamic> packageItems = widget.order['items'] ?? []; 

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.inventory_rounded, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(child: Text('مراجعة وتوجيه الطرد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 17))),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text("الزبون: $customerName\nالرقم: $trackingNum", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.blue.shade900), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 15),
              
              // 📦 عرض السلع بأمان
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                child: packageItems.isEmpty 
                  ? Padding(
                      padding: const EdgeInsets.all(15), 
                      child: Center(child: Text("لا توجد تفاصيل للسلع (طرد قديم)", style: GoogleFonts.cairo(color: Colors.grey)))
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(10),
                      itemCount: packageItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (context, index) {
                        var prod = packageItems[index];
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text("▪ ${prod['name'] ?? 'منتج غير معروف'}", style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(10)),
                              child: Text("الكمية: ${prod['qty'] ?? 0}", style: GoogleFonts.cairo(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                            )
                          ],
                        );
                      },
                    ),
              ),
              const SizedBox(height: 20),
              
              Text("اختر طريقة توجيه الطرد:", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 10),

              // 🛠️ الخيار 1: التسليم اليدوي
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10), color: Colors.grey.shade50),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("1. التوجيه اليدوي (بدون بطاقة):", style: GoogleFonts.cairo(fontSize: 13, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    
                    widget.fleet.isEmpty 
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("لا يوجد سائقون متاحون حالياً", style: GoogleFonts.cairo(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      : DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          hint: Text("اختر السائق من القائمة...", style: GoogleFonts.cairo(fontSize: 13)),
                          value: selectedDriverId,
                          items: widget.fleet.map((driver) {
                            bool isAvail = driver['status'] == 'متاح';
                            String dId = driver['id'].toString();
                            String dName = driver['first_name'] ?? driver['username'] ?? 'سائق';
                            
                            return DropdownMenuItem<String>(
                              value: dId,
                              child: Text("$dName ${isAvail ? '(🟢 متاح)' : '(🟠 مشغول)'}", style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => selectedDriverId = val),
                        ),
                    
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: selectedDriverId == null ? null : () => widget.onManualDispatch(selectedDriverId!),
                        child: Text("اعتماد السائق وتوجيه الطرد", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
              
              const SizedBox(height: 10),

              // ⚡ الخيار 2: التسليم السريع بالـ NFC
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: Colors.orange.shade300), borderRadius: BorderRadius.circular(10), color: Colors.orange.shade50),
                child: Column(
                  children: [
                    Text("2. التوجيه السريع والمصافحة الميدانية:", style: GoogleFonts.cairo(fontSize: 13, color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      icon: const Icon(Icons.nfc_rounded, size: 18),
                      label: Text('جاهز - امسح كرت السائق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                      onPressed: widget.onNfcDispatch,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}