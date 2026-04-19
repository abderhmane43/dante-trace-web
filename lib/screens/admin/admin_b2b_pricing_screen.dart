import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد فحص بيئة الويب
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 🔗 تأكد من مسار خدمة الـ API الخاص بك
import '../../services/api_service.dart';

class AdminB2BPricingScreen extends StatefulWidget {
  const AdminB2BPricingScreen({super.key});

  @override
  State<AdminB2BPricingScreen> createState() => _AdminB2BPricingScreenState();
}

class _AdminB2BPricingScreenState extends State<AdminB2BPricingScreen> {
  // 🎨 الألوان المؤسسية (Enterprise Colors)
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B);
  final Color softBg = const Color(0xFFF8FAFC);

  // 🗄️ متغيرات الحالة (State)
  bool _isLoadingData = true;
  bool _isSubmitting = false;
  
  List<dynamic> _customers = [];
  List<dynamic> _products = [];
  List<dynamic> _customerCustomPrices = [];

  String? _selectedCustomerId;
  String? _selectedProductId;
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  // 📡 1. جلب العملاء والمنتجات لملء القوائم المنسدلة
  Future<void> _fetchInitialData() async {
    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token') ?? '');
      final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

      final results = await Future.wait([
        http.get(Uri.parse('${ApiService.baseUrl}/users/'), headers: headers),
        http.get(Uri.parse('${ApiService.baseUrl}/customer/products'), headers: headers), // استخدام مسار المنتجات
      ]);

      if (results[0].statusCode == 200 && results[1].statusCode == 200) {
        final allUsers = jsonDecode(utf8.decode(results[0].bodyBytes)) as List;
        if (mounted) {
          setState(() {
            // فلترة المستخدمين ليكونوا زبائن فقط
            _customers = allUsers.where((u) => u['role'] == 'customer').toList();
            _products = jsonDecode(utf8.decode(results[1].bodyBytes));
            
            // حماية إضافية: إذا تم حذف المنتج المحدد، نقوم بتفريغ الاختيار
            if (_selectedProductId != null && !_products.any((p) => p['id'].toString() == _selectedProductId)) {
              _selectedProductId = null;
            }
            
            _isLoadingData = false;
          });
        }
      }
    } catch (e) {
      _showSnackBar("فشل في جلب البيانات الأساسية، تحقق من الاتصال.", Colors.red.shade800);
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  // 📡 2. جلب الأسعار المخصصة عند اختيار عميل معين
  Future<void> _fetchCustomPricesForCustomer(String customerId) async {
    final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token') ?? '');
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/customer-prices'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        final allPrices = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        setState(() {
          // جلب أسعار هذا العميل فقط
          _customerCustomPrices = allPrices.where((p) => p['customer_name'] == _customers.firstWhere((c) => c['id'].toString() == customerId)['username']).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching prices: $e");
    }
  }

  // 📡 3. إرسال السعر المخصص الجديد للسيرفر
  Future<void> _submitCustomPrice() async {
    if (_selectedCustomerId == null || _selectedProductId == null || _priceController.text.isEmpty) {
      _showSnackBar("يرجى إكمال جميع الحقول المطلوبة", Colors.orange.shade800);
      return;
    }

    final double? newPrice = double.tryParse(_priceController.text);
    if (newPrice == null || newPrice <= 0) {
      _showSnackBar("يرجى إدخال سعر صحيح أكبر من الصفر", Colors.red.shade800);
      return;
    }

    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();

    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token') ?? '');
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/admin/customer-price'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          "customer_id": int.parse(_selectedCustomerId!),
          "product_id": int.parse(_selectedProductId!),
          "custom_price": newPrice
        }),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          _showSnackBar("تم تطبيق السعر المخصص بنجاح ✅", Colors.green.shade700);
          _priceController.clear();
          _fetchCustomPricesForCustomer(_selectedCustomerId!); // تحديث القائمة فوراً
        } else {
          _showSnackBar("حدث خطأ أثناء حفظ السعر", Colors.red.shade800);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar("خطأ في الاتصال بالخادم", Colors.red.shade800);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // 🗑️ 4. حذف المنتج (تم إضافتها حديثاً)
  Future<void> _confirmAndDeleteProduct(int productId, String productName) async {
    // 1. إظهار نافذة تأكيد الحذف
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text("تأكيد الحذف", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("هل أنت متأكد أنك تريد حذف '$productName'؟ سيتم مسح أي أسعار مخصصة مرتبطة بهذا المنتج.", style: GoogleFonts.cairo(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey.shade700, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text("نعم، احذف", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white))
          )
        ],
      )
    ) ?? false;

    if (!confirm) return;

    // 2. إرسال طلب الحذف
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    final result = await ApiService.deleteProduct(productId);
    
    if (mounted) Navigator.pop(context); // إغلاق التحميل

    if (result["success"] == true) {
      _showSnackBar(result["message"], Colors.green.shade700);
      _fetchInitialData(); // تحديث القوائم لإزالة المنتج
      if (_selectedCustomerId != null) {
        _fetchCustomPricesForCustomer(_selectedCustomerId!); // تحديث الأسعار המخصصة
      }
    } else {
      // إظهار رسالة الخطأ (مثل لارتباطه بطلبيات)
      _showSnackBar(result["message"], Colors.red.shade800);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb; // 🔥 فحص الويب

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: Text("عروض الأسعار الخاصة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkBlue)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: darkBlue),
        centerTitle: true,
        // 🔥 إخفاء القائمة العلوية في المتصفح لتواجد الـ Sidebar
        leading: isDesktop ? const SizedBox.shrink() : null,
      ),
      body: _isLoadingData
          ? Center(child: CircularProgressIndicator(color: primaryRed))
          : Center(
              // 🔥 تقييد العرض في الويب لكي لا تتمدد الحقول
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductsList(), // 🔥 قائمة المنتجات القابلة للحذف
                      const SizedBox(height: 25),
                      
                      Text("تخصيص أسعار الزبائن", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                      const SizedBox(height: 15),
                      
                      _buildHeaderInfo(),
                      const SizedBox(height: 25),
                      _buildPricingForm(),
                      const SizedBox(height: 30),
                      
                      if (_selectedCustomerId != null) ...[
                        Text("الأسعار المخصصة الحالية للعميل", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                        const SizedBox(height: 15),
                        _buildCustomPricesList(isDesktop), // 🔥 نمرر كائن الويب هنا
                      ]
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // --- مكونات الواجهة (Widgets) ---

  // 🔥 ويدجت استعراض وحذف المنتجات
  Widget _buildProductsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("المنتجات المتوفرة (السوق)", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
              child: Text("${_products.length} منتج", style: GoogleFonts.poppins(color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
            )
          ],
        ),
        const SizedBox(height: 15),
        if (_products.isEmpty)
          Center(child: Text("لا توجد منتجات. قم بإضافة منتجات من الواجهة الرئيسية.", style: GoogleFonts.cairo(color: Colors.grey)))
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _products.length,
              itemBuilder: (ctx, index) {
                final p = _products[index];
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(radius: 18, backgroundColor: Colors.blue.shade50, child: Icon(Icons.inventory_2_rounded, size: 18, color: Colors.blue.shade700)),
                            const SizedBox(height: 10),
                            Text(p['name'], style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: darkBlue), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text("${p['price']} دج", style: GoogleFonts.poppins(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      // زر الحذف العائم
                      Positioned(
                        top: 0,
                        left: 0,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                          onPressed: () => _confirmAndDeleteProduct(p['id'], p['name']),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(child: Text("الأسعار المحددة هنا تتجاهل سعر السوق وتطبق حصرياً على العميل المختار.", style: GoogleFonts.cairo(fontSize: 13, color: Colors.blue.shade800, height: 1.3))),
        ],
      ),
    );
  }

  Widget _buildPricingForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(
        children: [
          // 1. اختيار العميل
          DropdownButtonFormField<String>(
            decoration: _inputDecoration("اختر العميل", Icons.storefront_rounded),
            value: _selectedCustomerId,
            items: _customers.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['username'], style: GoogleFonts.cairo()))).toList(),
            onChanged: (val) {
              setState(() => _selectedCustomerId = val);
              if (val != null) _fetchCustomPricesForCustomer(val);
            },
          ),
          const SizedBox(height: 15),

          // 2. اختيار المنتج
          DropdownButtonFormField<String>(
            decoration: _inputDecoration("اختر المنتج", Icons.inventory_2_outlined),
            value: _selectedProductId,
            items: _products.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['name'], style: GoogleFonts.cairo()))).toList(),
            onChanged: (val) => setState(() => _selectedProductId = val),
          ),
          const SizedBox(height: 15),

          // 3. السعر الجديد
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
            decoration: _inputDecoration("السعر المخصص (دج)", Icons.attach_money_rounded),
          ),
          const SizedBox(height: 25),

          // 4. زر الحفظ
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitCustomPrice,
              icon: _isSubmitting ? const SizedBox() : const Icon(Icons.check_circle_outline_rounded),
              label: _isSubmitting 
                  ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text("اعتماد السعر الخاص", style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: primaryRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCustomPricesList(bool isDesktop) {
    if (_customerCustomPrices.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("لا توجد أسعار مخصصة لهذا العميل حتى الآن.", style: GoogleFonts.cairo(color: Colors.grey))));
    }
    
    return isDesktop 
      // 🔥 في الويب نعرض الأسعار كـ Grid (بطاقتين في السطر)
      ? GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, 
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 3.5, // نسبة العرض للارتفاع
          ),
          itemCount: _customerCustomPrices.length,
          itemBuilder: (context, index) {
            return _buildPriceCard(_customerCustomPrices[index]);
          },
        )
      // 🔥 في الهاتف نعرضها كقائمة عمودية
      : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _customerCustomPrices.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPriceCard(_customerCustomPrices[index]),
            );
          },
        );
  }

  // أداة بناء بطاقة السعر المخصص
  Widget _buildPriceCard(Map<String, dynamic> item) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: Icon(Icons.local_offer_rounded, color: Colors.green.shade600, size: 20)),
        title: Text(item['product_name'] ?? 'منتج', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: darkBlue)),
        subtitle: Text("السعر الحصري المعتمد", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
        trailing: Text("${item['custom_price']} دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryRed, fontSize: 16)),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.cairo(color: Colors.grey.shade600),
      prefixIcon: Icon(icon, color: Colors.grey.shade500),
      filled: true,
      fillColor: softBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryRed.withOpacity(0.5), width: 1.5)),
    );
  }
}