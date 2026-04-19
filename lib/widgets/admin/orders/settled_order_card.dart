import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettledOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Function(int) onGeneratePdf;

  const SettledOrderCard({
    super.key,
    required this.order,
    required this.onGeneratePdf,
  });

  @override
  Widget build(BuildContext context) {
    final Color darkBlue = const Color(0xFF1E293B);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            // 🔥 تم التحديث هنا: استخدام withValues بدلاً من withOpacity
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- القسم العلوي: أيقونة الاستلام، اسم الزبون، والمبلغ ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 22),
              ),
              const SizedBox(width: 12),
              
              // 🔥 الحماية الأولى: Expanded لمنع انضغاط اسم الزبون أو تداخل النصوص
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order['customer_name'] ?? 'مجهول', 
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: darkBlue),
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "ID: ${order['tracking_number']?.toString().substring(0, order['tracking_number'].toString().length > 10 ? 10 : order['tracking_number'].toString().length) ?? '...'}", 
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 10),
              // عرض المبلغ وحالة الطلبية
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${order['cash_amount']} دج", 
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "مكتملة", 
                      style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                    ),
                  )
                ],
              )
            ],
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          
          // --- القسم السفلي: الموقع وزر طباعة الفاتورة ---
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 5),
              
              // 🔥 الحماية الثانية: Expanded لمنع انضغاط العنوان وضمان ظهور الزر بشكل صحيح
              Expanded(
                child: Text(
                  order['customer_address'] ?? 'غير محدد', 
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600), 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const SizedBox(width: 10),
              SizedBox(
                height: 35,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => onGeneratePdf(order['id']),
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: Text("الفاتورة", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}