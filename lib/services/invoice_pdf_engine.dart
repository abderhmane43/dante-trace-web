import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class InvoicePdfEngine {
  // 🔥 الدالة الرئيسية لتوليد وعرض الفاتورة (مجهزة بالـ QR Code)
  static Future<void> generateAndPrintInvoice(Map<String, dynamic> invoiceData) async {
    try {
      // 1. تحميل الخطوط العربية من جوجل
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicBoldFont = await PdfGoogleFonts.cairoBold();

      final pdf = pw.Document();
      
      // 2. فصل البيانات واستخراجها بذكاء
      final Map<String, dynamic> order = invoiceData.containsKey('order') ? invoiceData['order'] : invoiceData;
      final Map<String, dynamic>? driver = invoiceData['driver'];

      String trackingNum = order['tracking_number']?.toString() ?? 'N/A';
      String customerName = order['customer_name']?.toString() ?? 'زبون مجهول';
      String customerPhone = order['customer_phone']?.toString() ?? 'غير مدرج';
      String customerWilaya = order['customer_wilaya']?.toString() ?? '';
      String customerAddress = order['customer_address']?.toString() ?? 'غير مدرج';
      
      // 🛡️ تنسيق محاسبي للمبلغ
      double rawAmount = double.tryParse(order['amount']?.toString() ?? order['cash_amount']?.toString() ?? '0.0') ?? 0.0;
      final currencyFormat = NumberFormat('#,##0.00', 'en_US');
      String amount = currencyFormat.format(rawAmount);

      List<dynamic> items = order['items'] ?? [];
      
      // بيانات السائق
      String driverName = driver != null ? (driver['name']?.toString() ?? 'غير مدرج') : 'غير متوفر (استلام من المكتب)';
      String driverPhone = driver != null ? (driver['phone']?.toString() ?? 'غير مدرج') : '-';

      // تنسيق التاريخ الحالي للفاتورة
      String date = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

      // 3. بناء تصميم الصفحة (A4)
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl, // 👈 دعم الكتابة من اليمين لليسار
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBoldFont),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // --- الترويسة (Header) مع الـ QR Code ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("DANTE CLOUD ERP", style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.SizedBox(height: 5),
                        pw.Text("فاتورة مبيعات وإبراء ذمة مالية", style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                        pw.SizedBox(height: 10),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(5)),
                          child: pw.Text("رقم الفاتورة: $trackingNum", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900, fontSize: 12)),
                        )
                      ]
                    ),
                    // 🌟 إضافة الـ QR Code هنا
                    pw.Container(
                      padding: const pw.EdgeInsets.all(5),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300, width: 2),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: trackingNum, // سيتم مسح هذا الكود ليظهر رقم التتبع
                        width: 70,
                        height: 70,
                        color: PdfColors.blueGrey900,
                      ),
                    )
                  ]
                ),
                pw.SizedBox(height: 15),
                pw.Divider(thickness: 2, color: PdfColors.blue900),
                pw.SizedBox(height: 20),

                // --- معلومات الزبون والوقت ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("فاتورة إلى:", style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 12)),
                          pw.Text("السيد(ة): $customerName", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.Text("العنوان: ${customerWilaya.isNotEmpty ? '$customerWilaya - ' : ''}$customerAddress"),
                          pw.Text("الهاتف: $customerPhone"),
                        ]
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("تاريخ الإصدار:", style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 12)),
                        pw.Text(date, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 10),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: pw.BoxDecoration(color: PdfColors.green700, borderRadius: pw.BorderRadius.circular(5)),
                          child: pw.Text("حالة الدفع: مدفوعة بالكامل", style: const pw.TextStyle(color: PdfColors.white, fontSize: 12)),
                        )
                      ]
                    ),
                  ]
                ),
                pw.SizedBox(height: 15),

                // --- 🚚 صندوق معلومات اللوجستيات ---
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300)
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("المسؤول عن التوصيل: $driverName", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blueGrey800)),
                      pw.Text("هاتف الموظف: $driverPhone", style: const pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey800)),
                    ]
                  )
                ),
                pw.SizedBox(height: 20),

                // --- 📋 جدول المنتجات (بأبعاد هندسية دقيقة) ---
                pw.TableHelper.fromTextArray(
                  headers: ['المنتج', 'الكمية', 'السعر الإفرادي', 'المجموع'],
                  data: items.isEmpty 
                    ? [['لا توجد تفاصيل للسلع', '-', '-', '-']]
                    : items.map((item) {
                        double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                        int qty = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
                        return [
                          item['name']?.toString() ?? 'منتج مجهول', 
                          qty.toString(), 
                          "${currencyFormat.format(price)} دج",
                          "${currencyFormat.format(price * qty)} دج"
                        ];
                      }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
                  rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                  cellAlignment: pw.Alignment.center,
                  cellPadding: const pw.EdgeInsets.all(10),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(4), 
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                ),
                pw.SizedBox(height: 20),

                // --- 💰 الإجمالي ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green50, 
                        border: pw.Border.all(color: PdfColors.green),
                        borderRadius: pw.BorderRadius.circular(8)
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text("الإجمالي المدفوع: ", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.Text("$amount دج", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                        ]
                      )
                    )
                  ]
                ),
                pw.Spacer(),

                // --- ⚖️ التذييل القانوني ---
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    "هذه الفاتورة مستخرجة إلكترونياً من نظام Dante Trace وتعتبر وثيقة إبراء ذمة رسمية. نشكركم على ثقتكم بنا.", 
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600), 
                    textAlign: pw.TextAlign.center
                  ),
                ),
              ],
            );
          },
        ),
      );

      // 4. إطلاق نافذة الطباعة والمشاركة
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Invoice_${trackingNum.replaceAll(' ', '')}.pdf',
      );
      
    } catch (e) {
      debugPrint("🚨 PDF Engine Error: $e");
      throw Exception("فشل في توليد الفاتورة");
    }
  }
}