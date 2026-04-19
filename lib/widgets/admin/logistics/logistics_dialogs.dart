import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LogisticsDialogs {
  
  // 1. نافذة الانتظار أثناء قراءة بطاقة NFC
  static void showNfcWaitingDialog(BuildContext context, VoidCallback onCancel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nfc_rounded, size: 60, color: Colors.orange),
            const SizedBox(height: 15),
            Text("قرب بطاقة السائق لتأكيد تسليمه السلعة", textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),
            TextButton(
              onPressed: onCancel, 
              child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.red))
            )
          ],
        ),
      ),
    );
  }

  // 2. نافذة التوجيه اليدوي (للطرود الجاهزة)
  static void showManualDispatchDialog({
    required BuildContext context,
    required int orderId,
    required List<dynamic> fleet,
    required Function(int driverId) onAssign,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.local_shipping, color: Colors.deepPurple), 
            const SizedBox(width: 10), 
            Text("توجيه يدوي للطرد #$orderId", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16))
          ]
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: fleet.isEmpty 
            ? Text("لا يوجد سائقين في الأسطول حالياً.", style: GoogleFonts.cairo())
            : ListView.separated(
            shrinkWrap: true,
            itemCount: fleet.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final driver = fleet[index];
              bool isAvailable = driver['status'] == "متاح";
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isAvailable ? Colors.green.shade50 : Colors.orange.shade50, 
                  child: Icon(Icons.drive_eta, color: isAvailable ? Colors.green : Colors.orange)
                ),
                title: Text(driver['username'], style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  isAvailable ? "🟢 متاح للتوصيل" : "🟠 في مهمة (لديه طرود)", 
                  style: GoogleFonts.cairo(color: isAvailable ? Colors.green : Colors.orange, fontSize: 12)
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () {
                    Navigator.pop(context);
                    onAssign(driver['id']);
                  },
                  child: Text("توجيه", style: GoogleFonts.cairo(color: Colors.white, fontSize: 12)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}