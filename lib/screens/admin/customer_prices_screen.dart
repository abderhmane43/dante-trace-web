import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد مهم لفحص بيئة الويب
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

// 🔥 مسارات مطلقة لتفادي الأخطاء
import 'package:dante_trace_mobile/services/api_service.dart';
import 'package:dante_trace_mobile/widgets/admin/pricing/custom_price_form.dart';
import 'package:dante_trace_mobile/widgets/admin/pricing/custom_price_list_card.dart';

class CustomerPricesScreen extends StatefulWidget {
  const CustomerPricesScreen({super.key});

  @override
  State<CustomerPricesScreen> createState() => _CustomerPricesScreenState();
}

class _CustomerPricesScreenState extends State<CustomerPricesScreen> {
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B);
  final Color softBg = const Color(0xFFF8FAFC);
  
  List<dynamic> customers = [];
  List<dynamic> products = [];
  List<dynamic> customPricesList = [];

  // 🛡️ متغيرات صحيحة من نوع int للتعامل مع الـ Form الجديد
  int? selectedCustomerId;
  int? selectedProductId;
  double? originalPrice; 
  
  final TextEditingController priceController = TextEditingController();
  bool isLoading = true;
  bool hasError = false; 
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // 📥 جلب البيانات المتوازي باحترافية
  Future<void> _loadAllData() async {
    setState(() { isLoading = true; hasError = false; });
    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token') ?? '');
      final headers = {'Authorization': 'Bearer $token'};

      final results = await Future.wait([
        http.get(Uri.parse('${ApiService.baseUrl}/users/'), headers: headers).timeout(const Duration(seconds: 10)),
        http.get(Uri.parse('${ApiService.baseUrl}/products/'), headers: headers).timeout(const Duration(seconds: 10)),
        http.get(Uri.parse('${ApiService.baseUrl}/admin/customer-prices'), headers: headers).timeout(const Duration(seconds: 10)),
      ]);

      if (mounted) {
        setState(() {
          // 🛡️ فلترة آمنة للزبائن 
          if (results[0].statusCode == 200) {
            final allUsers = jsonDecode(utf8.decode(results[0].bodyBytes)) as List;
            customers = allUsers.where((u) => u['role']?.toString().toLowerCase() == 'customer').toList();
          }
          if (results[1].statusCode == 200) {
            products = jsonDecode(utf8.decode(results[1].bodyBytes));
          }
          if (results[2].statusCode == 200) {
            customPricesList = jsonDecode(utf8.decode(results[2].bodyBytes));
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() { isLoading = false; hasError = true; });
    }
  }

  // 💾 حفظ السعر
  Future<void> _saveCustomPrice() async {
    if (selectedCustomerId == null || selectedProductId == null || priceController.text.trim().isEmpty) {
      _showToast("⚠️ الرجاء اختيار الزبون والمنتج وتحديد السعر", Colors.orange.shade800);
      return;
    }

    final double? newPrice = double.tryParse(priceController.text.trim());
    if (newPrice == null || newPrice <= 0) {
      _showToast("⚠️ الرجاء إدخال سعر صحيح أكبر من الصفر", Colors.red.shade800);
      return;
    }

    setState(() => isSaving = true);
    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token') ?? '');
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/admin/customer-price'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          "customer_id": selectedCustomerId, 
          "product_id": selectedProductId, 
          "custom_price": newPrice
        }),
      );

      if (response.statusCode == 200 && mounted) {
        _showToast("✅ تم اعتماد السعر الخاص بنجاح", Colors.green.shade700);
        priceController.clear();
        setState(() { selectedCustomerId = null; selectedProductId = null; originalPrice = null; });
        _loadAllData(); // تحديث القائمة فوراً
      } else if (mounted) {
         _showToast("❌ حدث خطأ أثناء الحفظ. تأكد من البيانات.", Colors.red);
      }
    } catch (e) { 
      if (mounted) _showToast("❌ خطأ في الاتصال بالخادم", Colors.red);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showToast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(20),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb; // 🔥 فحص الويب

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: Text("عروض الأسعار الخاصة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)), 
        backgroundColor: primaryRed, 
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        // 🔥 إخفاء القائمة العلوية في المتصفح
        leading: isDesktop ? const SizedBox.shrink() : null,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        color: primaryRed,
        child: _buildBodyContent(isDesktop), // 🔥 تمرير isDesktop لدالة البناء
      ),
    );
  }

  Widget _buildBodyContent(bool isDesktop) {
    if (isLoading) return _buildShimmerLoading();
    if (hasError) return _buildErrorState();

    return Center(
      // 🔥 تقييد العرض ليناسب شاشات الكمبيوتر دون أن يتمدد
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔥 استدعاء الويدجت الخاص بالفورم بسلاسة تامة
              CustomPriceForm(
                customers: customers, 
                products: products,
                selectedCustomerId: selectedCustomerId, 
                selectedProductId: selectedProductId,
                originalPrice: originalPrice, 
                priceController: priceController,
                isSaving: isSaving,
                
                // 🛡️ التعيين المباشر الآمن بعد إصلاح الفورم (لا توجد خطوط حمراء بعد اليوم)
                onCustomerChanged: (val) {
                  setState(() {
                     selectedCustomerId = val;
                  });
                },
                onProductChanged: (val) {
                  setState(() {
                    selectedProductId = val;
                    if (selectedProductId != null) {
                      try {
                        var selectedProduct = products.firstWhere((p) => p['id'] == selectedProductId);
                        originalPrice = double.tryParse(selectedProduct['base_price'].toString());
                      } catch (e) {
                        originalPrice = null;
                      }
                    }
                  });
                },
                onSave: _saveCustomPrice,
              ),
              
              const SizedBox(height: 35),
              Text("الأسعار المخصصة الحالية 📋", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
              const SizedBox(height: 15),
              
              // 🔥 استدعاء قائمة البطاقات المعزولة مع التجاوب لشاشات الحاسوب
              customPricesList.isEmpty 
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text("لا توجد أسعار مخصصة حتى الآن", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  )
                : isDesktop 
                    ? GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, 
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 3.5, // نسبة العرض للارتفاع
                        ),
                        itemCount: customPricesList.length,
                        itemBuilder: (context, index) => CustomPriceListCard(item: customPricesList[index]),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: customPricesList.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CustomPriceListCard(item: customPricesList[index]),
                        ),
                      ),
            ],
          ),
        ),
      ),
    );
  }

  // 🪄 شاشة التحميل الوهمية
  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey.shade200, highlightColor: Colors.white, 
            child: Container(height: 350, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)))
          ),
          const SizedBox(height: 30),
          Shimmer.fromColors(
            baseColor: Colors.grey.shade200, highlightColor: Colors.white, 
            child: Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))
          ),
        ],
      ),
    );
  }

  // 🛑 شاشة الخطأ
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text("تعذر جلب البيانات من الخادم", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: primaryRed, foregroundColor: Colors.white),
            onPressed: _loadAllData, icon: const Icon(Icons.refresh_rounded), label: Text("إعادة المحاولة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
  }
}