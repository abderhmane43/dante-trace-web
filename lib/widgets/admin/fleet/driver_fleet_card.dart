import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // 🔥 استيراد مكتبة التنسيق المالي

class DriverFleetCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  final Function(int orderId, String customerName) onConfirmDelivery;

  const DriverFleetCard({
    super.key,
    required this.driver,
    required this.onConfirmDelivery,
  });

  @override
  Widget build(BuildContext context) {
    List<dynamic> activeOrders = driver['active_orders'] ?? [];
    bool isBusy = activeOrders.isNotEmpty;

    // 🛡️ استخراج اسم السائق بأمان
    String driverName = "سائق مجهول";
    if (driver['first_name'] != null && driver['first_name'].toString().trim().isNotEmpty) {
      driverName = driver['first_name'].toString().trim();
    } else if (driver['username'] != null) {
      driverName = driver['username'].toString().trim();
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isBusy ? Colors.orange.shade200 : Colors.green.shade200, width: 1.5)
      ),
      color: Colors.white,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        childrenPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isBusy ? Colors.orange.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(12)
          ),
          child: Icon(Icons.local_shipping_rounded, color: isBusy ? Colors.orange.shade700 : Colors.green.shade700),
        ),
        title: Text(driverName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF1E293B))),
        subtitle: Text(
          isBusy ? "في مهمة ميدانية (${activeOrders.length} طرود)" : "متاح بالمركز (لا يوجد مهام)", 
          style: GoogleFonts.cairo(color: isBusy ? Colors.orange.shade800 : Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold)
        ),
        children: [
          if (activeOrders.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18))
              ),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.inventory_2_rounded, size: 18, color: Colors.orange.shade900),
                      const SizedBox(width: 8),
                      Text("العهدة الحالية في شاحنته:", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...activeOrders.map((order) {
                    final String customer = order['customer_name']?.toString() ?? 'زبون غير معروف';
                    final String tracking = order['tracking_number']?.toString().split('-').last ?? '';
                    
                    // 🔥 التنسيق المالي
                    final double amountVal = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
                    final String formattedAmount = NumberFormat('#,##0.00').format(amountVal);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.orange.shade100),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        title: Text(customer, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text("المبلغ: $formattedAmount دج | التتبع: $tracking", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 11)),
                        trailing: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red.shade700,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                          ),
                          onPressed: () => onConfirmDelivery(order['id'], customer),
                          icon: const Icon(Icons.warning_rounded, size: 16),
                          label: Text("إنهاء يدوي\n(طوارئ)", textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, height: 1.2)),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18))),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade400, size: 40),
                  const SizedBox(height: 10),
                  Text("شاحنة فارغة ومستعدة للمهام", style: GoogleFonts.cairo(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                ],
              ),
            )
        ],
      ),
    );
  }
}