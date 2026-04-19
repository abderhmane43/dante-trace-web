import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // 🔥 استيراد مكتبة التنسيق المالي
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class ShipmentJourneyTimeline extends StatefulWidget {
  final Map<String, dynamic> order;

  const ShipmentJourneyTimeline({super.key, required this.order});

  @override
  State<ShipmentJourneyTimeline> createState() => _ShipmentJourneyTimelineState();
}

class _ShipmentJourneyTimelineState extends State<ShipmentJourneyTimeline> {
  List<dynamic> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _fetchOrderHistory();
  }

  // 📡 جلب السجل الزمني الحقيقي من قاعدة البيانات
  Future<void> _fetchOrderHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/orders/${widget.order['id']}/history'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _history = jsonDecode(utf8.decode(response.bodyBytes));
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingHistory = false);
    }
  }

  // 🖨️ دالة فتح روابط الـ PDF للطباعة
  Future<void> _launchPrintURL(String endpoint) async {
    final Uri url = Uri.parse('${ApiService.baseUrl}/admin/orders/${widget.order['id']}/$endpoint');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تعذر فتح وثيقة الطباعة")));
    }
  }

  @override
  Widget build(BuildContext context) {
    String status = widget.order['delivery_status'] ?? 'pending';
    String trackingNum = widget.order['tracking_number'] ?? '-';
    
    // 🔥 التنسيق المالي لإجمالي الطلبية الذي يظهر في رأس السجل
    final double amount = double.tryParse(widget.order['cash_amount']?.toString() ?? '0') ?? 0.0;
    final String formattedAmount = NumberFormat('#,##0.00').format(amount);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // شريط السحب العلوي
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("سجل تتبع الشحنة", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                  Row(
                    children: [
                      Text("تتبع: $trackingNum", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 10),
                      Text("|", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade300)),
                      const SizedBox(width: 10),
                      Text("$formattedAmount دج", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                    ],
                  ),
                ],
              ),
              _buildStatusChip(status),
            ],
          ),
          const SizedBox(height: 20),

          // 📜 عرض السجل الزمني الحقيقي
          Expanded(
            child: _isLoadingHistory 
              ? const Center(child: CircularProgressIndicator())
              : _history.isEmpty 
                ? Center(child: Text("لا توجد حركات مسجلة بعد", style: GoogleFonts.cairo(color: Colors.grey)))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final log = _history[index];
                      return _buildHistoryNode(
                        title: log['action'],
                        actor: log['actor_name'],
                        time: log['timestamp'],
                        notes: log['notes'] ?? "",
                        isLast: index == _history.length - 1,
                      );
                    },
                  ),
          ),

          const SizedBox(height: 15),

          // 🛠️ لوحة أزرار الطباعة الذكية (تتغير حسب الحالة)
          Column(
            children: [
              if (status == 'pending' || status == 'approved')
                _buildPrintButton("طباعة أمر تجهيز المخزن", Icons.inventory_2_rounded, Colors.blueGrey, "picking-list"),
              
              if (status == 'assigned' || status == 'picked_up')
                _buildPrintButton("طباعة بيان تسليم السائق", Icons.local_shipping_rounded, Colors.orange.shade800, "waybill"),
              
              if (status == 'delivered' || status == 'delivered_unpaid')
                _buildPrintButton("طباعة وصل استلام الزبون", Icons.person_pin_circle_rounded, Colors.green.shade700, "customer-receipt"),
              
              if (status == 'settled')
                _buildPrintButton("طباعة تقرير التصفية النهائية", Icons.verified_user_rounded, const Color(0xFF1E293B), "customer-receipt"),
            ],
          ),
        ],
      ),
    );
  }

  // تصميم عقدة التاريخ الزمني
  Widget _buildHistoryNode({required String title, required String actor, required String time, required String notes, required bool isLast}) {
    DateTime date = DateTime.parse(time);
    String formattedTime = DateFormat('HH:mm | yyyy-MM-dd').format(date);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.check_circle, size: 20, color: Colors.blue),
            if (!isLast) Container(width: 2, height: 60, color: Colors.blue.withOpacity(0.2)),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B))),
              Text("بواسطة: $actor", style: GoogleFonts.cairo(fontSize: 12, color: Colors.blue.shade700)),
              Text(formattedTime, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
              if (notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(notes, style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrintButton(String label, IconData icon, Color color, String endpoint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: () => _launchPrintURL(endpoint),
          icon: Icon(icon, size: 18),
          label: Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
    );
  }
}