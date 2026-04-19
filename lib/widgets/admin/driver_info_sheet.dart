import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DriverInfoSheet extends StatelessWidget {
  final Map<String, dynamic> driver;

  const DriverInfoSheet({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    final Color darkBlue = const Color(0xFF1E293B);
    final Color successGreen = const Color(0xFF2E7D32);
    final Color warningOrange = const Color(0xFFEF6C00);

    // 💰 حساب وتنسيق العهدة (السيولة)
    final double balance = double.tryParse(driver['current_cash_balance']?.toString() ?? '0') ?? 0.0;
    final String formattedBalance = NumberFormat('#,##0.00').format(balance);
    
    // 📦 الطرود النشطة
    final List<dynamic> activeOrders = driver['active_orders'] ?? [];

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🛑 مؤشر السحب والإغلاق
            Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),

            // 👤 رأس الملف (بيانات السائق الأساسية)
            Row(
              children: [
                CircleAvatar(radius: 30, backgroundColor: Colors.orange.shade100, child: Icon(Icons.person, size: 35, color: warningOrange)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver['first_name'] ?? driver['username'] ?? 'سائق', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: darkBlue, height: 1.2)),
                      Text("ID: ${driver['id']}  |  NFC: ${driver['driver_nfc_id'] ?? 'غير مربوط'}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: activeOrders.isEmpty && balance == 0 ? successGreen.withOpacity(0.1) : warningOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(activeOrders.isEmpty && balance == 0 ? "متاح تماماً" : "في مهمة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12, color: activeOrders.isEmpty && balance == 0 ? successGreen : warningOrange)),
                )
              ],
            ),
            
            const SizedBox(height: 25),

            // 🚚 مسار السائق الحي (Timeline)
            Text("المسار الحي للسائق 📍", style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: darkBlue)),
            const SizedBox(height: 15),
            _buildDriverJourneyTimeline(activeOrders, balance),

            const SizedBox(height: 25),

            // 💰 بطاقة السيولة المالية
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.shade200), boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 10)]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("السيولة في عهدته الآن", style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                      Text("$formattedBalance دج", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: successGreen)),
                    ],
                  ),
                  Icon(Icons.account_balance_wallet_rounded, size: 40, color: successGreen.withOpacity(0.2)),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 📦 قائمة المهام النشطة
            Text("المهام الحالية (${activeOrders.length})", style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: darkBlue)),
            const SizedBox(height: 10),
            Expanded(
              child: activeOrders.isEmpty
                  ? Center(child: Text("لا توجد طلبيات بحوزته حالياً", style: GoogleFonts.cairo(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: activeOrders.length,
                      itemBuilder: (context, index) {
                        final order = activeOrders[index];
                        return Card(
                          elevation: 0, margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(Icons.local_shipping, color: Colors.blue, size: 18)),
                            title: Text(order['customer_name'] ?? 'زبون', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text("${order['tracking_number']}", style: GoogleFonts.poppins(fontSize: 11)),
                            trailing: Text("${order['cash_amount']} دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: darkBlue)),
                          ),
                        );
                      },
                    ),
            )
          ],
        ),
      ),
    );
  }

  // 🪄 أداة بناء المسار الديناميكي للسائق
  Widget _buildDriverJourneyTimeline(List<dynamic> activeOrders, double balance) {
    // تحليل حالة السائق بناءً على البيانات
    bool hasAssigned = activeOrders.any((o) => o['delivery_status'] == 'assigned'); // مسندة ولم يستلمها من المخزن
    bool hasInTransit = activeOrders.any((o) => o['delivery_status'] == 'picked_up' || o['delivery_status'] == 'in_transit'); // استلمها وانطلق
    bool hasCash = balance > 0; // قام بالتسليم وجمع أموالاً

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildTimelineNode(Icons.coffee_rounded, "متاح للمهام", true, true),
          _buildTimelineDivider(hasAssigned || hasInTransit || hasCash),
          
          _buildTimelineNode(Icons.assignment_ind_rounded, "تم إسناد طرود", hasAssigned || hasInTransit || hasCash, hasAssigned && !hasInTransit && !hasCash),
          _buildTimelineDivider(hasInTransit || hasCash),
          
          _buildTimelineNode(Icons.local_shipping_rounded, "في الميدان (توصيل)", hasInTransit || hasCash, hasInTransit && !hasCash),
          _buildTimelineDivider(hasCash),
          
          _buildTimelineNode(Icons.payments_rounded, "يحمل سيولة (يحتاج تصفية)", hasCash, hasCash),
        ],
      ),
    );
  }

  Widget _buildTimelineNode(IconData icon, String label, bool isReached, bool isActiveNow) {
    Color nodeColor = isReached ? (isActiveNow ? Colors.blue.shade600 : Colors.green.shade600) : Colors.grey.shade300;
    return Column(
      children: [
        Container(
          width: 45, height: 45,
          decoration: BoxDecoration(
            color: isReached ? Colors.white : Colors.grey.shade100,
            shape: BoxShape.circle,
            border: Border.all(color: nodeColor, width: isActiveNow ? 3 : 2),
            boxShadow: isActiveNow ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)] : [],
          ),
          child: Icon(icon, color: nodeColor, size: 20),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.cairo(fontSize: 10, fontWeight: isActiveNow ? FontWeight.bold : FontWeight.normal, color: isReached ? const Color(0xFF1E293B) : Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildTimelineDivider(bool isPassed) {
    return Container(
      width: 40, height: 3,
      margin: const EdgeInsets.only(bottom: 20),
      color: isPassed ? Colors.green.shade600 : Colors.grey.shade300,
    );
  }
}