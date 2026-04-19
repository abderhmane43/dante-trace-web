import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverStatusTimeline extends StatelessWidget {
  final List<dynamic> activeOrders;
  final double currentBalance;

  const DriverStatusTimeline({
    super.key,
    required this.activeOrders,
    required this.currentBalance,
  });

  @override
  Widget build(BuildContext context) {
    bool isWarehouse = activeOrders.any((o) => o['delivery_status'] == 'assigned');
    bool isOnRoad = activeOrders.any((o) => o['delivery_status'] == 'picked_up' || o['delivery_status'] == 'in_transit');
    bool hasCash = currentBalance > 0;
    bool isIdle = activeOrders.isEmpty && currentBalance <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStep(Icons.home_work_rounded, "متاح", isIdle, isIdle),
            _buildLine(isWarehouse || isOnRoad || hasCash),
            _buildStep(Icons.inventory_2_rounded, "بالمخزن", isWarehouse || isOnRoad || hasCash, isWarehouse && !isOnRoad),
            _buildLine(isOnRoad || hasCash),
            _buildStep(Icons.local_shipping_rounded, "في الطريق", isOnRoad || hasCash, isOnRoad),
            _buildLine(hasCash),
            _buildStep(Icons.payments_rounded, "للتحصيل", hasCash, hasCash),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(IconData icon, String title, bool isReached, bool isActive) {
    Color color = isReached ? (isActive ? Colors.blue.shade700 : Colors.green.shade600) : Colors.grey.shade300;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isReached ? Colors.white : Colors.grey.shade50,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isActive ? 3 : 2),
            boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)] : [],
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(title, style: GoogleFonts.cairo(fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isReached ? Colors.black87 : Colors.grey)),
      ],
    );
  }

  Widget _buildLine(bool isPassed) {
    return Container(width: 30, height: 2, margin: const EdgeInsets.only(bottom: 22), color: isPassed ? Colors.green.shade600 : Colors.grey.shade300);
  }
}