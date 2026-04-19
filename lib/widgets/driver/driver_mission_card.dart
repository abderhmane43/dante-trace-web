import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; // 🔥 تم استيراد مكتبة التنسيق المالي
// 🔥 استيراد مكون شريط التقدم المرئي
import '../shared/order_timeline_widget.dart';

class DriverMissionCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onDeliver; // 🔥 تفتح قائمة (كاش / دين)
  final VoidCallback onPickUp;  // 🔥 تستدعي NFC المخزن

  const DriverMissionCard({
    super.key,
    required this.order,
    required this.onDeliver,
    required this.onPickUp,
  });

  // 📞 دالة الاتصال الهاتفي السريع
  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // 🗺️ دالة فتح خرائط جوجل (البحث بالعنوان)
  Future<void> _openMaps(String address, String? wilaya) async {
    String query = Uri.encodeComponent("$address, ${wilaya ?? ''} Algeria");
    final Uri launchUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // استخراج حالة الطرد
    final String status = order['delivery_status']?.toString() ?? 'assigned';
    final String approvalStatus = order['customer_approval_status']?.toString() ?? 'not_required';
    
    // استخراج محتويات الطلبية (القطع)
    final List<dynamic> items = order['items'] ?? [];
    
    // هل الطرد لا يزال في المخزن؟
    final bool needsPickUp = status == 'assigned';

    // 🔥 تنسيق المبلغ الإجمالي للطرد (0.00)
    final double cashAmount = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
    final String formattedCash = NumberFormat('#,##0.00').format(cashAmount);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 👤 رأس البطاقة: الزبون وحالة الدفع
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                            child: Icon(Icons.person_pin_rounded, color: Colors.orange.shade800),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(order['customer_name'] ?? 'زبون', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text("رقم التتبع: ${order['tracking_number']?.toString().substring(0, 8)}...", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Text("$formattedCash دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 14)),
                    )
                  ],
                ),
                const Divider(height: 20),

                // 📦 تفاصيل محتويات الطلبية (الجديد)
                if (items.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueGrey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("📦 تفاصيل المحتوى:", style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900)),
                        const SizedBox(height: 8),
                        ...items.map((item) {
                          final String name = item['name']?.toString() ?? 'قطعة';
                          final int qty = item['qty'] ?? 1;
                          final double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                          
                          // 🔥 تنسيق سعر القطعة الواحدة (0.00)
                          final String formattedPrice = NumberFormat('#,##0.00').format(price);
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(name, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800))),
                                Text("$qty × $formattedPrice دج", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
                
                // 📍 تفاصيل العنوان
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text("${order['customer_wilaya'] ?? ''} - ${order['customer_address'] ?? 'العنوان غير مسجل'}", style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey.shade800))),
                  ],
                ),
                const SizedBox(height: 20),

                // 🎛️ أزرار الإجراءات السريعة (اتصال، خرائط)
                Row(
                  children: [
                    // زر الاتصال
                    Expanded(
                      flex: 1,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => _makeCall(order['customer_phone']),
                        child: Icon(Icons.phone_enabled_rounded, color: Colors.blue.shade700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // زر الخرائط
                    Expanded(
                      flex: 1,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade50, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => _openMaps(order['customer_address'], order['customer_wilaya']),
                        child: Icon(Icons.map_rounded, color: Colors.amber.shade800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 🔥 زر الإجراء الرئيسي الذكي (يتغير حسب الحالة)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: needsPickUp
                      ? ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700, 
                            foregroundColor: Colors.white, 
                            elevation: 2, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          onPressed: onPickUp, // 🔥 يفتح شاشة الـ NFC مباشرة للاستلام من المخزن
                          icon: const Icon(Icons.nfc_rounded, size: 20),
                          label: Text("استلام العهدة (NFC)", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700, 
                            foregroundColor: Colors.white, 
                            elevation: 2, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          onPressed: onDeliver, // 🔥 يفتح النافذة السفلية لاختيار (كاش + NFC) أو (دين)
                          icon: const Icon(Icons.check_circle_rounded, size: 20),
                          label: Text("خيارات التسليم للزبون", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                ),
              ],
            ),
          ),
          
          // 🔥 شريط التقدم المرئي في الأسفل
          Container(
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(top: BorderSide(color: Colors.grey.shade100))
            ),
            child: OrderTimelineWidget(
              currentStatus: status,
              approvalStatus: approvalStatus,
            ),
          )
        ],
      ),
    );
  }
}