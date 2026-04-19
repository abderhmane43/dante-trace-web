import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

import '../../services/api_service.dart';
import '../shared/login_screen.dart';

class CustomerShopScreen extends StatefulWidget {
  const CustomerShopScreen({super.key});

  @override
  State<CustomerShopScreen> createState() => _CustomerShopScreenState();
}

class _CustomerShopScreenState extends State<CustomerShopScreen> {
  final Color primaryColor = const Color(0xFF2563EB); // أزرق تجاري
  
  bool _isLoading = true;
  String _customerName = "زبوننا الكريم";
  List<dynamic> _products = [];
  
  // سلة المشتريات: {product_id: {product_data, qty}}
  final Map<int, Map<String, dynamic>> _cart = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _customerName = prefs.getString('username') ?? "زبوننا الكريم";
    
    // جلب المنتجات بالأسعار المخصصة لهذا الزبون تحديداً
    final products = await ApiService.getDynamicProducts();
    
    if (mounted) {
      setState(() {
        _products = products;
        _isLoading = false;
      });
    }
  }

  // 🛒 إدارة السلة
  void _addToCart(dynamic product) {
    setState(() {
      int id = product['id'];
      if (_cart.containsKey(id)) {
        _cart[id]!['qty'] += 1;
      } else {
        _cart[id] = {'product': product, 'qty': 1};
      }
    });
  }

  void _removeFromCart(int productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        if (_cart[productId]!['qty'] > 1) {
          _cart[productId]!['qty'] -= 1;
        } else {
          _cart.remove(productId);
        }
      }
    });
  }

  double _getCartTotal() {
    double total = 0;
    _cart.forEach((key, item) {
      total += (item['product']['price'] * item['qty']);
    });
    return total;
  }

  // 📦 نافذة إتمام الطلب (Checkout)
  void _showCheckoutBottomSheet() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("السلة فارغة!", style: GoogleFonts.cairo()), backgroundColor: Colors.orange));
      return;
    }

    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final wilayaController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 25),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("إتمام الطلب 🚀", style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                      Text("${_getCartTotal()} دج", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                    ],
                  ),
                  const Divider(height: 30),
                  
                  // 🔥 إضافة: عرض ملخص سريع للقطع المختارة قبل التأكيد
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("ملخص القطع المطلوبة:", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor)),
                        const SizedBox(height: 5),
                        ..._cart.values.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("• ${item['product']['name']}", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade800)),
                              Text("x${item['qty']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor)),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text("بيانات التوصيل:", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "رقم الهاتف", prefixIcon: const Icon(Icons.phone), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 10),
                  TextField(controller: wilayaController, decoration: InputDecoration(labelText: "الولاية", prefixIcon: const Icon(Icons.map), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 10),
                  TextField(controller: addressController, decoration: InputDecoration(labelText: "العنوان بالتفصيل", prefixIcon: const Icon(Icons.location_on), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: isSubmitting ? null : () async {
                        if (phoneController.text.isEmpty || addressController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى ملء الهاتف والعنوان"), backgroundColor: Colors.red));
                          return;
                        }

                        setModalState(() => isSubmitting = true);

                        // تجهيز قائمة المنتجات للباك إند
                        List<Map<String, dynamic>> orderItems = _cart.values.map((item) => {
                          "name": item['product']['name'],
                          "qty": item['qty'],
                          "price": item['product']['price']
                        }).toList();

                        // إنشاء رقم تتبع عشوائي احترافي
                        String trackingNum = "DANTE-ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";

                        Map<String, dynamic> orderData = {
                          "tracking_number": trackingNum,
                          "customer_name": _customerName,
                          "customer_phone": phoneController.text,
                          "customer_address": addressController.text,
                          "customer_wilaya": wilayaController.text,
                          "cash_amount": _getCartTotal(),
                          "items": orderItems
                        };

                        bool success = await ApiService.createCustomerOrder(orderData);
                        
                        if (!mounted) return;
                        Navigator.pop(ctx);

                        if (success) {
                          setState(() => _cart.clear()); // تفريغ السلة
                          showDialog(
                            context: context, 
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
                              title: Text("تم استلام طلبك!", textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                              content: Text("رقم التتبع:\n$trackingNum\n\nسيقوم فريقنا بمراجعة الطلب وإسناده للسائق قريباً.", textAlign: TextAlign.center, style: GoogleFonts.cairo()),
                              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً"))],
                            )
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("حدث خطأ أثناء إرسال الطلب"), backgroundColor: Colors.red));
                        }
                      },
                      child: isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text("تأكيد وإرسال الطلب", style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  void _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    int totalItems = _cart.values.fold(0, (sum, item) => sum + (item['qty'] as int));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text("Dante Market", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.grey), onPressed: _logout),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text("مرحباً بك، $_customerName 👋", style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text("تصفح المنتجات بأسعار الجملة المخصصة لك", style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey.shade600)),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _products.isEmpty
                    ? Center(child: Text("لا توجد منتجات متاحة حالياً", style: GoogleFonts.cairo(color: Colors.grey)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(15),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final prod = _products[index];
                          int qtyInCart = _cart[prod['id']]?['qty'] ?? 0;

                          return Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Icon(Icons.inventory_2_rounded, size: 50, color: primaryColor.withValues(alpha: 0.5)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(prod['name'], textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                ),
                                Text("${prod['price']} دج", style: GoogleFonts.poppins(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
                                
                                // أزرار الإضافة للسلة
                                qtyInCart == 0 
                                  ? ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                                      label: Text("إضافة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                      onPressed: () => _addToCart(prod),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => _removeFromCart(prod['id'])),
                                        Text("$qtyInCart", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                        IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => _addToCart(prod)),
                                      ],
                                    )
                              ],
                            ),
                          );
                        },
                      ),
              )
            ],
          ),
      // 🛒 الشريط السفلي العائم للسلة (يظهر فقط إذا كان هناك منتجات)
      bottomNavigationBar: _cart.isEmpty ? null : Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("الإجمالي ($totalItems منتج)", style: GoogleFonts.cairo(color: Colors.grey.shade600, fontSize: 12)),
                Text("${_getCartTotal()} دج", style: GoogleFonts.poppins(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              onPressed: _showCheckoutBottomSheet,
              child: Text("إتمام الطلب", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}