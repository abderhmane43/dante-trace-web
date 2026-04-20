import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MasterPinDialog {
  // دالة تفتح نافذة تطلب الرقم السري وتُرجعه عند الضغط على تأكيد
  static Future<String?> show(BuildContext context) async {
    TextEditingController pinController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false, // لا يمكن للمستخدم إغلاقها بالضغط خارج النافذة
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 10),
              Text("صلاحيات المدير", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red.shade800)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "هذه العملية حساسة جداً ولا يمكن التراجع عنها. يرجى إدخال الرمز السري للمدير العام (Master PIN) لتأكيد الحذف.",
                style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinController,
                obscureText: true, // إخفاء الرقم كنقاط (****)
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 5),
                decoration: InputDecoration(
                  hintText: "****",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15), 
                    borderSide: const BorderSide(color: Colors.red, width: 2)
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null), // إرجاع null عند الإلغاء
              child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
              ),
              onPressed: () {
                // إرجاع الرقم الذي تم إدخاله عند الضغط على تأكيد
                Navigator.pop(context, pinController.text.trim());
              },
              child: Text("تأكيد الحذف", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}