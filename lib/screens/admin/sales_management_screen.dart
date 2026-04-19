import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد مهم لفحص بيئة الويب
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
// 🔥 استدعاء الـ Widgets المجزأة (تأكد من بقاء ملفاتها في مشروعك)
import '../../widgets/admin/sales/add_product_forms.dart';
import '../../widgets/admin/sales/products_list_tab.dart';

class SalesManagementScreen extends StatefulWidget {
  const SalesManagementScreen({super.key});

  @override
  State<SalesManagementScreen> createState() => _SalesManagementScreenState();
}

class _SalesManagementScreenState extends State<SalesManagementScreen> {
  final Color primaryIndigo = Colors.indigo.shade800;
  final Color backgroundGray = const Color(0xFFF4F7F9);

  final TextEditingController prodNameController = TextEditingController();
  final TextEditingController prodPriceController = TextEditingController();
  String selectedIcon = 'videocam';
  bool isAddingProduct = false;

  final TextEditingController customerIdController = TextEditingController();
  final TextEditingController productIdController = TextEditingController();
  final TextEditingController customPriceController = TextEditingController();
  bool isSettingPrice = false;

  List<dynamic> _productsList = [];
  bool isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts(); 
  }

  // ==========================================
  // 📦 1. جلب قائمة المنتجات
  // ==========================================
  Future<void> _fetchProducts() async {
    setState(() => isLoadingProducts = true);
    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token'));
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/customer/products'), 
        headers: {'Authorization': 'Bearer $token'}
      );

      if (response.statusCode == 200 && mounted) {
        setState(() => _productsList = jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        _showSnackBar("❌ فشل في جلب المنتجات", Colors.red.shade800);
      }
    } catch (e) {
      debugPrint("Error fetching products: $e");
      _showSnackBar("❌ تعذر الاتصال بالخادم", Colors.red.shade800);
    } finally {
      if (mounted) setState(() => isLoadingProducts = false);
    }
  }

  // ==========================================
  // ➕ 2. إضافة منتج جديد للمخزن
  // ==========================================
  Future<void> _addProduct() async {
    if (prodNameController.text.isEmpty || prodPriceController.text.isEmpty) {
      _showSnackBar("⚠️ يرجى تعبئة اسم المنتج والسعر", Colors.orange.shade800);
      return;
    }
    
    setState(() => isAddingProduct = true);
    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token'));
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/admin/products'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          "name": prodNameController.text.trim(), 
          "base_price": double.parse(prodPriceController.text), 
          "icon_name": selectedIcon
        })
      );
      
      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          _showSnackBar("✅ تم إضافة المنتج للمخزن بنجاح!", Colors.green.shade700);
          prodNameController.clear(); 
          prodPriceController.clear();
          _fetchProducts(); 
        } else {
          _showSnackBar("❌ حدث خطأ أثناء إضافة المنتج", Colors.red.shade800);
        }
      }
    } catch (e) {
      _showSnackBar("❌ خطأ في الاتصال بالخادم", Colors.red.shade800);
    } finally {
      if (mounted) setState(() => isAddingProduct = false);
    }
  }

  // ==========================================
  // 🗑️ 3. حذف منتج من المخزن
  // ==========================================
  Future<void> _deleteProduct(int productId, String productName) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.red), const SizedBox(width: 10), Text("تأكيد الحذف", style: GoogleFonts.cairo(fontWeight: FontWeight.bold))]),
        content: Text("هل أنت متأكد أنك تريد حذف ($productName) نهائياً؟\nسيتم حذف جميع أسعار الجملة المرتبطة به أيضاً.", style: GoogleFonts.cairo(height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), 
            onPressed: () => Navigator.pop(context, true), 
            child: Text("نعم، احذف", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold))
          )
        ],
      )
    );

    if (confirm != true) return;

    setState(() => isLoadingProducts = true);
    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token'));
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/admin/products/$productId'), 
        headers: {'Authorization': 'Bearer $token'}
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 204) {
          _showSnackBar("✅ تم حذف المنتج بنجاح", Colors.green.shade700);
          _fetchProducts(); 
        } else {
          _showSnackBar("❌ فشل الحذف، قد يكون مرتبطاً بطلبات سابقة لا يمكن مسحها.", Colors.red.shade800);
        }
      }
    } catch (e) {
      _showSnackBar("❌ خطأ في الاتصال بالخادم", Colors.red.shade800);
    } finally {
      if (mounted) setState(() => isLoadingProducts = false);
    }
  }

  // ==========================================
  // 🏢 4. تحديد سعر خاص لزبون (B2B Pricing)
  // ==========================================
  Future<void> _setCustomPrice() async {
    if (customerIdController.text.isEmpty || productIdController.text.isEmpty || customPriceController.text.isEmpty) {
      _showSnackBar("⚠️ يرجى تعبئة جميع حقول التسعير الخاص", Colors.orange.shade800);
      return;
    }
    
    setState(() => isSettingPrice = true);
    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token'));
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/admin/customer-price'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          "customer_id": int.parse(customerIdController.text), 
          "product_id": int.parse(productIdController.text), 
          "custom_price": double.parse(customPriceController.text)
        })
      );
      
      if (mounted) {
        if (response.statusCode == 200) {
          _showSnackBar("✅ تم تفعيل تسعير الجملة للشركة/الزبون بنجاح!", Colors.green.shade700);
          customerIdController.clear(); 
          productIdController.clear(); 
          customPriceController.clear();
        } else if (response.statusCode == 404) {
          _showSnackBar("❌ الزبون أو المنتج غير موجود في النظام", Colors.red.shade800);
        } else {
          _showSnackBar("❌ حدث خطأ أثناء تفعيل السعر الخاص", Colors.red.shade800);
        }
      }
    } catch (e) {
      _showSnackBar("❌ خطأ في الاتصال بالخادم", Colors.red.shade800);
    } finally {
      if (mounted) setState(() => isSettingPrice = false);
    }
  }

  // 🛠️ دالة مساعدة لإظهار التنبيهات بسهولة
  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(20),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb; // 🔥 فحص الويب

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: backgroundGray,
        appBar: AppBar(
          title: Text("إدارة المنتجات والمخزن", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: primaryIndigo, 
          foregroundColor: Colors.white, 
          elevation: 0,
          centerTitle: true,
          // 🔥 إخفاء زر القائمة العلوية في المتصفح لتواجد الـ Sidebar
          leading: isDesktop ? const SizedBox.shrink() : null,
          bottom: TabBar(
            indicatorColor: Colors.white, 
            indicatorWeight: 4,
            labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15), 
            unselectedLabelStyle: GoogleFonts.cairo(fontSize: 14),
            tabs: const [
              Tab(icon: Icon(Icons.add_business_rounded), text: "إضافة وتسعير"), 
              Tab(icon: Icon(Icons.inventory_2_rounded), text: "كتالوج المنتجات")
            ],
          ),
        ),
        body: Center(
          // 🔥 تقييد العرض في شاشات الحاسوب لكي لا تتمدد الحقول بشكل مزعج
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : double.infinity),
            child: TabBarView(
              children: [
                // 🔥 استدعاء الويدجت الخاص بالفورم
                AddProductForms(
                  prodNameController: prodNameController, 
                  prodPriceController: prodPriceController,
                  selectedIcon: selectedIcon, 
                  onIconChanged: (val) => setState(() => selectedIcon = val!),
                  isAddingProduct: isAddingProduct, 
                  onAddProduct: _addProduct,
                  customerIdController: customerIdController, 
                  productIdController: productIdController, 
                  customPriceController: customPriceController,
                  isSettingPrice: isSettingPrice, 
                  onSetCustomPrice: _setCustomPrice,
                ),
                // 🔥 استدعاء الويدجت الخاص بالقائمة
                ProductsListTab(
                  isLoading: isLoadingProducts, 
                  productsList: _productsList,
                  onRefresh: _fetchProducts, 
                  onDeleteProduct: _deleteProduct,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}