import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AddProductForms extends StatelessWidget {
  final TextEditingController prodNameController;
  final TextEditingController prodPriceController;
  final String selectedIcon;
  final ValueChanged<String?> onIconChanged;
  final bool isAddingProduct;
  final VoidCallback onAddProduct;

  final TextEditingController customerIdController;
  final TextEditingController productIdController;
  final TextEditingController customPriceController;
  final bool isSettingPrice;
  final VoidCallback onSetCustomPrice;

  const AddProductForms({
    super.key,
    required this.prodNameController,
    required this.prodPriceController,
    required this.selectedIcon,
    required this.onIconChanged,
    required this.isAddingProduct,
    required this.onAddProduct,
    required this.customerIdController,
    required this.productIdController,
    required this.customPriceController,
    required this.isSettingPrice,
    required this.onSetCustomPrice,
  });

  final Color primaryIndigo = const Color(0xFF283593); // Colors.indigo.shade800

  InputDecoration _inputStyle(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.cairo(fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: Colors.blueGrey) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Widget _buildFormCard({required String title, required String subtitle, required IconData icon, required Color color, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black..withValues(alpha:0.04), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color..withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 28)),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)), Text(subtitle, style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey))])),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSubmitButton(String text, bool isLoading, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity, height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
        onPressed: isLoading ? null : onPressed,
        child: isLoading ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(text, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              // 📦 القسم الأول: إضافة منتج للسوق
              _buildFormCard(
                title: "إضافة منتج جديد للسوق",
                subtitle: "سيظهر هذا المنتج لجميع الزبائن بالسعر الافتراضي",
                icon: Icons.add_business_rounded,
                color: primaryIndigo,
                children: [
                  TextField(controller: prodNameController, decoration: _inputStyle("اسم المنتج (مثال: داش كام)")),
                  const SizedBox(height: 15),
                  TextField(controller: prodPriceController, keyboardType: TextInputType.number, decoration: _inputStyle("السعر الافتراضي (دج)", icon: Icons.attach_money)),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: selectedIcon, decoration: _inputStyle("أيقونة المنتج", icon: Icons.image_outlined),
                    items: [
                      DropdownMenuItem(value: 'videocam', child: Text("كاميرا ذكية 📹", style: GoogleFonts.cairo())),
                      DropdownMenuItem(value: 'nfc', child: Text("شريحة NFC 🏷️", style: GoogleFonts.cairo())),
                      DropdownMenuItem(value: 'location', child: Text("جهاز تتبع GPS 📍", style: GoogleFonts.cairo())),
                      DropdownMenuItem(value: 'tablet', child: Text("جهاز لوحي 📱", style: GoogleFonts.cairo())),
                    ],
                    onChanged: onIconChanged,
                  ),
                  const SizedBox(height: 20),
                  _buildSubmitButton("حفظ المنتج في الكتالوج", isAddingProduct, onAddProduct, primaryIndigo),
                ],
              ),

              const SizedBox(height: 25),

              // 🤝 القسم الثاني: تسعير الجملة (B2B)
              _buildFormCard(
                title: "عروض أسعار خاصة (B2B)",
                subtitle: "تحديد سعر مخفض لزبون معين بناءً على العقود",
                icon: Icons.handshake_rounded,
                color: Colors.amber.shade800,
                children: [
                  Row(
                    children: [
                      Expanded(child: TextField(controller: customerIdController, keyboardType: TextInputType.number, decoration: _inputStyle("رقم الزبون (ID)", icon: Icons.person))),
                      const SizedBox(width: 15),
                      Expanded(child: TextField(controller: productIdController, keyboardType: TextInputType.number, decoration: _inputStyle("رقم المنتج (ID)", icon: Icons.inventory_2))),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextField(controller: customPriceController, keyboardType: TextInputType.number, decoration: _inputStyle("السعر المخفض المتفق عليه (دج)", icon: Icons.price_check)),
                  const SizedBox(height: 20),
                  _buildSubmitButton("اعتماد السعر للزبون", isSettingPrice, onSetCustomPrice, Colors.amber.shade800),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}