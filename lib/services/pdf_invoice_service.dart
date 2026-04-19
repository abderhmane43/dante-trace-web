import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfInvoiceService {
  
  /// 🖨️ دالة توليد وطباعة الفاتورة الحرارية
  static Future<void> generateAndPrintInvoice(Map<String, dynamic> invoiceData) async {
    try {
      final pdf = pw.Document();

      // 📥 1. جلب الخطوط العربية من Google Fonts لدعم الكتابة من اليمين لليسار (RTL)
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicBoldFont = await PdfGoogleFonts.cairoBold();

      // 📄 2. إنشاء صفحة بمقاس Roll80 (المقاس العالمي لطابعات الفواتير المحمولة 80mm)
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80, 
          theme: pw.ThemeData.withFont(
            base: arabicFont,
            bold: arabicBoldFont,
          ),
          textDirection: pw.TextDirection.rtl, // 🌟 تفعيل دعم اللغة العربية
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // 🏢 ترويسة الشركة
                pw.SizedBox(height: 10),
                pw.Text("DANTE TRACE LOGISTICS", style: pw.TextStyle(font: arabicBoldFont, fontSize: 16)),
                pw.Text("نظام الإدارة اللوجستية المتقدم", style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 10),
                pw.Text("--- إيصال استلام ---", style: pw.TextStyle(font: arabicBoldFont, fontSize: 14)),
                pw.SizedBox(height: 15),
                
                // 📝 معلومات الفاتورة والزبون
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("رقم الإيصال: ${invoiceData['invoice_number'] ?? '-'}", style: const pw.TextStyle(fontSize: 10)),
                      pw.Text("التاريخ: ${invoiceData['date'] ?? '-'}", style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 5),
                      pw.Text("الزبون: ${invoiceData['customer_name'] ?? '-'}", style: pw.TextStyle(font: arabicBoldFont, fontSize: 12)),
                      pw.Text("العنوان: ${invoiceData['customer_address'] ?? '-'}", style: const pw.TextStyle(fontSize: 10)),
                      pw.Text("الهاتف: ${invoiceData['customer_phone'] ?? '-'}", style: const pw.TextStyle(fontSize: 10)),
                      if (invoiceData['driver_name'] != null && invoiceData['driver_name'] != "غير محدد")
                        pw.Text("تم التوصيل بواسطة: ${invoiceData['driver_name']}", style: const pw.TextStyle(fontSize: 10)),
                    ]
                  )
                ),
                pw.SizedBox(height: 15),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 5),
                
                // 📦 جدول المنتجات
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("المنتج", style: pw.TextStyle(font: arabicBoldFont, fontSize: 12)),
                    pw.Text("الكمية", style: pw.TextStyle(font: arabicBoldFont, fontSize: 12)),
                  ]
                ),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dotted),
                
                // التكرار على قائمة المنتجات ديناميكياً
                if (invoiceData['items'] != null)
                  ...List.generate((invoiceData['items'] as List).length, (index) {
                    final item = invoiceData['items'][index];
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(child: pw.Text(item['name'] ?? 'منتج غير معروف', style: const pw.TextStyle(fontSize: 11))),
                          pw.Text("x${item['qty'] ?? 1}", style: pw.TextStyle(font: arabicBoldFont, fontSize: 12)),
                        ]
                      )
                    );
                  }),
                
                pw.SizedBox(height: 5),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 5),
                
                // 💰 الإجمالي المطلوب الدفع
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("الإجمالي المطلوب:", style: pw.TextStyle(font: arabicBoldFont, fontSize: 14)),
                    pw.Text("${invoiceData['total_amount']} دج", style: pw.TextStyle(font: arabicBoldFont, fontSize: 16)),
                  ]
                ),
                pw.SizedBox(height: 25),
                
                // 🔲 الباركود (QR Code) لتتبع الطلبية لاحقاً
                pw.BarcodeWidget(
                  data: invoiceData['tracking_number'] ?? "DANTE-UNKNOWN",
                  barcode: pw.Barcode.qrCode(),
                  width: 80,
                  height: 80,
                ),
                pw.SizedBox(height: 5),
                pw.Text(invoiceData['tracking_number'] ?? "", style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 20),
                
                // 🤝 تذييل الفاتورة
                pw.Text("شكراً لثقتكم بنا!", style: pw.TextStyle(font: arabicBoldFont, fontSize: 12)),
                pw.Text("Dante Trace ERP System", style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 20), // مساحة بيضاء لقص الورق في الطابعة
              ],
            );
          },
        ),
      );

      // 🖨️ 3. استدعاء واجهة الطباعة (تسمح باختيار طابعة بلوتوث أو حفظ كملف PDF)
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Receipt_${invoiceData['tracking_number'] ?? 'DANTE'}.pdf',
      );

    } catch (e) {
      debugPrint("❌ Print Error: $e");
    }
  }
}