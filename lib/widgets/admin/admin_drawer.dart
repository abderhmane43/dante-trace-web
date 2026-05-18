import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/admin/shipment_journey_timeline.dart';

class AdminArchiveScreen extends StatefulWidget {
  const AdminArchiveScreen({super.key});

  @override
  State<AdminArchiveScreen> createState() => _AdminArchiveScreenState();
}

class _AdminArchiveScreenState extends State<AdminArchiveScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await ApiService.searchAllOrders(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _searchResults = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ أثناء البحث", style: GoogleFonts.cairo()), backgroundColor: Colors.red));
      }
    }
  }

  void _showJourneySheet(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ShipmentJourneyTimeline(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("أرشيف الطلبيات الشامل", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Column(
        children: [
          // 🔍 حقل البحث
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _performSearch(),
                    decoration: InputDecoration(
                      hintText: "ابحث برقم التتبع، الاسم، أو الهاتف...",
                      hintStyle: GoogleFonts.cairo(fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      filled: true,
                      fillColor: Colors.blue.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _performSearch,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: const EdgeInsets.all(14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Icon(Icons.manage_search_rounded, color: Colors.white),
                )
              ],
            ),
          ),
          
          // 📋 نتائج البحث
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (!_hasSearched)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.library_books_rounded, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 15),
                          Text("ابحث في سجل جميع الطلبيات المؤرشفة", style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  : _searchResults.isEmpty
                      ? Center(child: Text("لا توجد نتائج مطابقة لبحثك", style: GoogleFonts.cairo(fontSize: 16, color: Colors.red.shade400, fontWeight: FontWeight.bold)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(15),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final order = _searchResults[index];
                            
                            // 🔥 تأمين الحسابات والنصوص ضد الـ null
                            final String customerName = order['customer_name'] ?? 'زبون غير معروف';
                            final String trackingNum = order['tracking_number']?.toString() ?? '-';
                            final String orderStatus = order['delivery_status']?.toString().toUpperCase() ?? 'PENDING';
                            
                            final double amount = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
                            final double settledCash = double.tryParse(order['settled_cash_amount']?.toString() ?? '0') ?? 0.0;
                            final double settledCheck = double.tryParse(order['settled_check_amount']?.toString() ?? '0') ?? 0.0;
                            final double remaining = double.tryParse(order['remaining_amount']?.toString() ?? '0') ?? 0.0;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 2,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(15),
                                onTap: () => _showJourneySheet(order),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(backgroundColor: Colors.blue.shade50, child: Icon(Icons.archive_rounded, color: Colors.blue.shade800)),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(customerName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E293B))),
                                            const SizedBox(height: 4),
                                            Text("تتبع: $trackingNum", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                                            const SizedBox(height: 6),
                                            
                                            // تفاصيل الدفع
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text("الإجمالي:", style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade700)),
                                                      Text("${NumberFormat('#,##0.00').format(amount)} دج", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                  if (settledCash > 0 || settledCheck > 0)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 4.0),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text("المدفوع:", style: GoogleFonts.cairo(fontSize: 11, color: Colors.green.shade700)),
                                                          Text("كاش(${NumberFormat('#,##0').format(settledCash)}) | شيك(${NumberFormat('#,##0').format(settledCheck)})", style: GoogleFonts.cairo(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                                                        ],
                                                      ),
                                                    ),
                                                  if (remaining > 0)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 4.0),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text("المتبقي دين:", style: GoogleFonts.cairo(fontSize: 11, color: Colors.red.shade700)),
                                                          Text("${NumberFormat('#,##0.00').format(remaining)} دج", style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: orderStatus.contains('SETTLED') ? Colors.teal.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                            child: Text(orderStatus, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: orderStatus.contains('SETTLED') ? Colors.teal.shade800 : Colors.blue.shade800)),
                                          ),
                                          const SizedBox(height: 20),
                                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
          ),
        ],
      ),
    );
  }
}