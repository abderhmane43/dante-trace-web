import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderReviewCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onReview;
  final VoidCallback? onSplit; // 🔥 دالة التقسيم (اختيارية)

  const OrderReviewCard({
    super.key, 
    required this.order, 
    required this.onReview,
    this.onSplit, // تمرير دالة التقسيم من الشاشة الأب
  });

  @override
  Widget build(BuildContext context) {
    bool isSubOrder = order['parent_shipment_id'] != null;
    String status = order['delivery_status'] ?? 'pending';
    String approvalStatus = order['customer_approval_status'] ?? 'not_required';
    
    // 🔥 الحالات الجديدة
    bool isPendingApproval = status == 'pending_approval' && approvalStatus == 'pending';
    bool isPending = status == 'pending';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        // 🔥 إطار بنفسجي إذا كانت الطلبية تنتظر موافقة الزبون
        side: isPendingApproval 
            ? const BorderSide(color: Colors.purple, width: 1.5) 
            : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 15),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: isPendingApproval ? Colors.purple.shade50 : (isSubOrder ? Colors.purple.shade50 : Colors.orange.shade50),
          child: Icon(
            isPendingApproval ? Icons.schedule_send_rounded : (isSubOrder ? Icons.call_split_rounded : Icons.pending_actions_rounded),
            color: isPendingApproval ? Colors.purple : (isSubOrder ? Colors.purple : Colors.deepOrange),
          ),
        ),
        title: Text(order['customer_name'] ?? 'مجهول', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "${order['customer_wilaya'] ?? 'غير محدد'} • ${order['cash_amount']} دج",
              style: GoogleFonts.cairo(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              "تتبع: ${order['tracking_number'].toString()}",
              style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // 🔥 رسالة تنبيهية تظهر للأدمن ليعرف أن الطلبية معلقة عند الزبون
            if (isPendingApproval)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "⏳ بانتظار موافقة الزبون على الموعد المقترح",
                  style: GoogleFonts.cairo(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min, // لكي لا تأخذ مساحة كبيرة
          children: [
            // 🔥 زر التقسيم البنفسجي يظهر فقط إذا كانت الطلبية معلقة وتم تمرير دالة التقسيم
            if (isPending && onSplit != null) ...[
              IconButton(
                onPressed: onSplit,
                icon: const Icon(Icons.content_cut_rounded, size: 20),
                color: Colors.purple,
                tooltip: "تقسيم الطلبية",
                style: IconButton.styleFrom(backgroundColor: Colors.purple.shade50),
              ),
              const SizedBox(width: 5),
            ],
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey.shade800,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onReview,
              child: Text("مراجعة", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}