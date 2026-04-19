import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomPriceListCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const CustomPriceListCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black..withValues(alpha:0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12), 
            decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle), 
            child: const Icon(Icons.star_rounded, color: Colors.purple, size: 24)
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['customer_name'] ?? 'زبون', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E293B))),
                Text(item['product_name'] ?? 'منتج', style: GoogleFonts.cairo(color: Colors.blueGrey, fontSize: 13, height: 1.2)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
            child: Text("${item['custom_price']} دج", style: GoogleFonts.poppins(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 14)),
          )
        ],
      ),
    );
  }
}