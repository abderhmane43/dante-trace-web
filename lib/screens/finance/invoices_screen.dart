import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart'; // 🔥 للتنسيق المالي

// مسار الـ API
import '../../services/api_service.dart';

// 🔥 استيراد محرك الطباعة الفخم
import '../../services/invoice_pdf_engine.dart'; 

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B);
  final Color backgroundGray = const Color(0xFFF8FAFC);
  final Color masterPurple = const Color(0xFF673AB7); 

  bool _isLoading = true;
  List<dynamic> _allInvoices = [];
  List<dynamic> _filteredInvoices = [];
  
  String _selectedFilter = 'all'; 
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAllOrders();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 📥 جلب كل الطلبيات
  Future<void> _fetchAllOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/all-orders'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=utf-8'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _allInvoices = data;
            _applyFilters();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        _showToast("حدث خطأ في الخادم: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showToast("تعذر الاتصال بالسيرفر", Colors.orange.shade900);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredInvoices = _allInvoices.where((inv) {
        final name = inv['customer_name']?.toString().toLowerCase() ?? '';
        final tracking = inv['tracking_number']?.toString().toLowerCase() ?? '';
        final matchesSearch = name.contains(query) || tracking.contains(query);

        final status = inv['delivery_status']?.toString() ?? '';
        bool matchesStatus = true;
        
        switch (_selectedFilter) {
          case 'pending': matchesStatus = status == 'pending' || status == 'approved' || status == 'pending_approval'; break;
          case 'transit': matchesStatus = status == 'assigned' || status == 'picked_up' || status == 'in_transit'; break;
          case 'delivered': matchesStatus = status == 'delivered' || status == 'delivered_unpaid' || status == 'assigned_to_collector'; break;
          case 'settled': matchesStatus = status == 'settled' || status == 'settled_with_collector'; break;
          default: matchesStatus = true; 
        }

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> _showInvoiceDetails(int shipmentId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/invoice-data/$shipmentId'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=utf-8'},
      ).timeout(const Duration(seconds: 15));

      if (mounted) Navigator.pop(context); 

      if (response.statusCode == 200) {
        final invoiceData = jsonDecode(utf8.decode(response.bodyBytes));
        _buildReceiptDialog(invoiceData, shipmentId); 
      } else {
        _showToast("تعذر جلب تفاصيل الفاتورة", Colors.red);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showToast("تعذر الاتصال بالسيرفر", Colors.orange.shade900);
    }
  }

  Future<void> _approveDebtCollection(int shipmentId, BuildContext dialogCtx) async {
    Navigator.pop(dialogCtx); 
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/admin/shipments/$shipmentId/approve-debt-collection'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (mounted) {
        if (response.statusCode == 200) {
          _showToast("✅ تمت الموافقة! الدين يظهر الآن في شاشة المحصلين.", Colors.green.shade700);
          _fetchAllOrders();
        } else {
          setState(() => _isLoading = false);
          _showToast("❌ حدث خطأ أثناء التكليف", Colors.red.shade800);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showToast("❌ تعذر الاتصال بالسيرفر", Colors.orange.shade900);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGray,
      appBar: AppBar(
        title: Text("مركز الفواتير الشامل", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: primaryRed,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "ابحث برقم التتبع أو اسم الزبون...",
                        hintStyle: GoogleFonts.cairo(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildFilterChip('all', 'الكل', Icons.dashboard_rounded),
                      _buildFilterChip('pending', 'معلقة', Icons.hourglass_empty_rounded),
                      _buildFilterChip('transit', 'في الطريق', Icons.local_shipping_rounded),
                      _buildFilterChip('delivered', 'التسليم / الديون', Icons.check_circle_outline_rounded),
                      _buildFilterChip('settled', 'مصفاة مالياً', Icons.account_balance_wallet_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? _buildShimmerLoading()
                : RefreshIndicator(
                    onRefresh: _fetchAllOrders,
                    color: primaryRed,
                    child: _filteredInvoices.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _filteredInvoices.length,
                            itemBuilder: (context, index) {
                              return _buildInvoiceCard(_filteredInvoices[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String title, IconData icon) {
    bool isSelected = _selectedFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: FilterChip(
        label: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? primaryRed : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? primaryRed : Colors.grey.shade700)),
          ],
        ),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            _selectedFilter = filterKey;
            _applyFilters();
          });
        },
        backgroundColor: Colors.white.withOpacity(0.9),
        selectedColor: Colors.white,
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? Colors.white : Colors.transparent)),
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final String customerName = invoice['customer_name'] ?? 'زبون غير معروف';
    final String tracking = invoice['tracking_number'] ?? 'N/A';
    
    // 🔥 تنسيق المبلغ (0.00)
    final double amount = double.tryParse(invoice['cash_amount']?.toString() ?? '0.0') ?? 0.0;
    final String formattedAmount = NumberFormat('#,##0.00').format(amount);

    final int id = invoice['id'];
    final String status = invoice['delivery_status'] ?? 'pending';
    final bool isMaster = invoice['is_master'] == true;
    final bool isSubBatch = invoice['master_shipment_id'] != null;

    Color statusColor = Colors.grey;
    String statusText = 'مجهول';
    IconData statusIcon = Icons.help_outline;

    if (status == 'pending' || status == 'approved' || status == 'pending_approval') {
      statusColor = Colors.orange; statusText = 'قيد الانتظار'; statusIcon = Icons.hourglass_bottom_rounded;
    } else if (status == 'assigned' || status == 'picked_up' || status == 'in_transit') {
      statusColor = Colors.blue; statusText = 'في الطريق'; statusIcon = Icons.local_shipping_rounded;
    } else if (status == 'delivered') {
      statusColor = Colors.green; statusText = 'تم الدفع 💵'; statusIcon = Icons.task_alt_rounded;
    } else if (status == 'delivered_unpaid') {
      statusColor = Colors.deepOrange; statusText = 'دين معلق 📝'; statusIcon = Icons.warning_rounded; 
    } else if (status == 'assigned_to_collector') { 
      statusColor = Colors.teal; statusText = 'مُسند للمحصل 🏃‍♂️'; statusIcon = Icons.directions_run_rounded; 
    } else if (status == 'settled_with_collector') {
      statusColor = Colors.indigo; statusText = 'عهدة المحصل 💼'; statusIcon = Icons.account_balance_wallet_rounded; 
    } else if (status == 'settled') {
      statusColor = primaryRed; statusText = 'مغلقة مالياً 🔒'; statusIcon = Icons.verified_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showInvoiceDetails(id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isMaster ? masterPurple.withOpacity(0.1) : statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(isMaster ? Icons.account_tree_rounded : (isSubBatch ? Icons.call_split_rounded : statusIcon), color: isMaster ? masterPurple : statusColor, size: 26),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(customerName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: darkBlue), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (isMaster)
                            Container(
                              margin: const EdgeInsets.only(right: 5),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(color: masterPurple, borderRadius: BorderRadius.circular(4)),
                              child: Text("طلبية أم", style: GoogleFonts.cairo(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          if (isSubBatch)
                            Container(
                              margin: const EdgeInsets.only(right: 5),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(color: Colors.orange.shade800, borderRadius: BorderRadius.circular(4)),
                              child: Text("دفعة فرعية", style: GoogleFonts.cairo(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      Text("تتبع: $tracking", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("$formattedAmount دج", style: GoogleFonts.poppins(color: darkBlue, fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text(statusText, style: GoogleFonts.cairo(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🧾 النافذة المنبثقة المحدثة (معلومات كاملة + تنسيق 0.00) 🔥
  void _buildReceiptDialog(Map<String, dynamic> data, int shipmentId) { 
    final orderData = data.containsKey('order') ? data['order'] : data;
    final items = orderData['items'] as List<dynamic>? ?? [];

    // 🔥 تنسيق المجموع النهائي
    final double totalAmount = double.tryParse(orderData['amount']?.toString() ?? orderData['cash_amount']?.toString() ?? '0') ?? 0.0;
    final String formattedTotal = NumberFormat('#,##0.00').format(totalAmount);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_rounded, size: 50, color: darkBlue),
              const SizedBox(height: 10),
              Text("DANTE TRACE", style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 20, color: darkBlue, letterSpacing: 2)),
              Text("تفاصيل الطلبية والفاتورة", style: GoogleFonts.cairo(color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 20),
              
              _buildReceiptRow("رقم الفاتورة:", orderData['invoice_number'] ?? 'N/A'),
              _buildReceiptRow("رقم التتبع:", orderData['tracking_number'] ?? 'N/A'),
              _buildReceiptRow("التاريخ:", orderData['date'] ?? 'N/A'),
              _buildReceiptRow("الزبون:", orderData['customer_name'] ?? 'N/A'),
              _buildReceiptRow("الهاتف:", orderData['customer_phone'] ?? 'N/A'),
              _buildReceiptRow("العنوان:", orderData['customer_address'] ?? 'N/A'),
              
              const SizedBox(height: 15),
              const _DashedLine(),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(flex: 3, child: Text("المنتج", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 1, child: Text("كمية", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("المجموع", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.left)),
                ],
              ),
              const SizedBox(height: 10),
              
              if (items.isEmpty)
                Text("لا توجد تفاصيل للمنتجات", style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12))
              else
                ...items.map((item) {
                  final double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                  final int qty = item['qty'] ?? 1;
                  final String subTotal = NumberFormat('#,##0.00').format(price * qty);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text("• ${item['name']}", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade800))),
                        Expanded(flex: 1, child: Text("x$qty", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                        Expanded(flex: 2, child: Text("$subTotal", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: darkBlue), textAlign: TextAlign.left)),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 15),
              const _DashedLine(),
              const SizedBox(height: 15),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("المجموع النهائي:", style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 18, color: darkBlue)),
                  Text("$formattedTotal دج", style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 20, color: primaryRed)),
                ],
              ),
              
              const SizedBox(height: 30),
              
              if (orderData['status'] == 'delivered_unpaid') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () => _approveDebtCollection(shipmentId, ctx),
                    icon: const Icon(Icons.assignment_ind_rounded, size: 20),
                    label: Text("تكليف المحصل بجمع الدين", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("إغلاق", style: GoogleFonts.cairo(color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed, 
                        foregroundColor: Colors.white, 
                        padding: const EdgeInsets.symmetric(vertical: 12), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), 
                        elevation: 0
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx); 
                        _showToast("جاري تجهيز الفاتورة للطباعة 🖨️...", Colors.blue.shade700);
                        try {
                          await InvoicePdfEngine.generateAndPrintInvoice(data);
                        } catch (e) {
                          _showToast("حدث خطأ أثناء إنشاء ملف الـ PDF", Colors.red);
                        }
                      },
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: Text("طباعة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: GoogleFonts.cairo(color: Colors.grey.shade600, fontSize: 12))),
          Expanded(child: Text(value, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: darkBlue), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text("لا توجد فواتير في هذه الفئة", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
        child: Container(height: 90, margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18))),
      ),
    );
  }

  void _showToast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(20),
    ));
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth, height: dashHeight,
              child: DecoratedBox(decoration: BoxDecoration(color: Colors.grey.shade400)),
            );
          }),
        );
      },
    );
  }
}