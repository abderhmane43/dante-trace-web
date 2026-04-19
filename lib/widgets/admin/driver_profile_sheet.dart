import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'driver_status_timeline.dart'; 

class DriverProfileSheet extends StatelessWidget {
  final Map<String, dynamic> driverData;

  const DriverProfileSheet({super.key, required this.driverData});

  @override
  Widget build(BuildContext context) {
    final double balance = double.tryParse(driverData['current_cash_balance']?.toString() ?? '0') ?? 0.0;
    final List<dynamic> activeOrders = driverData['active_orders'] ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          
          Row(
            children: [
              CircleAvatar(radius: 30, backgroundColor: Colors.blue.shade100, child: Icon(Icons.person, size: 35, color: Colors.blue.shade800)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driverData['first_name'] ?? driverData['username'] ?? 'سائق', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("NFC: ${driverData['driver_nfc_id'] ?? 'غير مربوط'}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              _buildStatusBadge(activeOrders.isEmpty && balance <= 0),
            ],
          ),
          
          const SizedBox(height: 25),
          Text("المسار الميداني الحي", style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          const SizedBox(height: 10),
          DriverStatusTimeline(activeOrders: activeOrders, currentBalance: balance),
          const SizedBox(height: 20),
          
          Container(
            width: double.infinity, padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green.shade700, Colors.green.shade900]), borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("السيولة (العهدة الحالية)", style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
                    Text("${NumberFormat('#,##0.00').format(balance)} دج", style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Icon(Icons.account_balance_wallet_rounded, color: Colors.white30, size: 40),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          Text("الطرود التي بحوزته الآن (${activeOrders.length})", style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          Flexible(
            child: activeOrders.isEmpty 
              ? Center(child: Text("لا توجد مهام نشطة حالياً", style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13)))
              : ListView.builder(
                  shrinkWrap: true, itemCount: activeOrders.length,
                  itemBuilder: (ctx, index) {
                    final o = activeOrders[index];
                    return Card(
                      elevation: 0, margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        leading: const Icon(Icons.inventory_2_rounded, color: Colors.blue),
                        title: Text(o['customer_name'] ?? 'زبون', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(o['tracking_number'] ?? '', style: GoogleFonts.poppins(fontSize: 10)),
                        trailing: Text("${o['cash_amount']} دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isIdle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: isIdle ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(15)),
      child: Text(isIdle ? "متاح" : "في مهمة", style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: isIdle ? Colors.green.shade700 : Colors.orange.shade800)),
    );
  }
}