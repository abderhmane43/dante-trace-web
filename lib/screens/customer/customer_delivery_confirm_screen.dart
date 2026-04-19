import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../services/api_service.dart';

class CustomerDeliveryConfirmScreen extends StatefulWidget {
  const CustomerDeliveryConfirmScreen({super.key});

  @override
  State<CustomerDeliveryConfirmScreen> createState() => _CustomerDeliveryConfirmScreenState();
}

class _CustomerDeliveryConfirmScreenState extends State<CustomerDeliveryConfirmScreen> {
  final Color primaryBlue = const Color(0xFF1976D2);
  final Color successGreen = const Color(0xFF2E7D32);
  final Color bgGray = const Color(0xFFF4F7F9);
  
  bool _isLoading = true;
  List<dynamic> _arrivingOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchArrivingOrders();
  }

  Future<void> _fetchArrivingOrders() async {
    setState(() => _isLoading = true);
    try {
      final fetchedOrders = await ApiService.getCustomerHistory();
      
      if (mounted) {
        setState(() {
          // جلب الطلبيات التي هي في الطريق فقط (جاهزة للاستلام)
          _arrivingOrders = fetchedOrders.where((o) => o['delivery_status'] == 'picked_up' || o['delivery_status'] == 'in_transit').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showToast("حدث خطأ في جلب البيانات", Colors.red);
    }
  }

  // 🛡️ دالة تأكيد الاستلام من طرف الزبون
  void _confirmReceiptManually(int orderId, String trackingNumber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.verified_user_rounded, color: successGreen),
            const SizedBox(width: 10),
            Text("تأكيد الاستلام", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: successGreen)),
          ],
        ),
        content: Text(
          "هل تؤكد استلامك للطلبية رقم ($trackingNumber) ودفع المبلغ المطلوب للسائق؟\n\nبضغطك على 'تأكيد'، سيتم إغلاق الطلبية نهائياً.",
          style: GoogleFonts.cairo(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("تراجع", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: successGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx); // إغلاق الديالوج
              _showLoadingOverlay();
              
              // 🔥 تحديث الحالة إلى 'delivered' مباشرة من حساب الزبون
              bool success = await ApiService.updateOrderStatus(orderId, 'delivered');
              
              if (mounted && Navigator.canPop(context)) Navigator.pop(context); // إغلاق اللودينغ

              if (success) {
                _showToast("✅ شكراً لك! تم تأكيد الاستلام بنجاح.", successGreen);
                _fetchArrivingOrders(); // تحديث القائمة
              } else {
                _showToast("❌ حدث خطأ في الاتصال بالخادم.", Colors.red);
              }
            },
            child: Text("نعم، أؤكد الاستلام", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLoadingOverlay() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
  }

  void _showToast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.all(20),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGray,
      appBar: AppBar(
        title: Text("تأكيد استلام الطرود 📦", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: successGreen,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading 
        ? _buildShimmer()
        : _arrivingOrders.isEmpty 
            ? _buildEmptyState() 
            : _buildOrdersList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_rounded, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text("لا توجد طرود في الطريق إليك حالياً", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return RefreshIndicator(
      color: successGreen,
      onRefresh: _fetchArrivingOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _arrivingOrders.length,
        itemBuilder: (context, index) {
          final order = _arrivingOrders[index];
          final double amount = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
          final String formattedAmount = NumberFormat('#,##0.00').format(amount);

          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade50,
                    child: Icon(Icons.local_shipping_rounded, color: Colors.orange.shade700),
                  ),
                  title: Text(order['tracking_number'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text("المبلغ المطلوب: $formattedAmount دج", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: successGreen.withOpacity(0.05),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12)
                    ),
                    onPressed: () => _confirmReceiptManually(order['id'], order['tracking_number']),
                    icon: const Icon(Icons.check_circle_outline, size: 22),
                    label: Text("أنا استلمت الطرد من السائق", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      itemBuilder: (ctx, i) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200, highlightColor: Colors.white,
        child: Container(height: 150, margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
      ),
    );
  }
}