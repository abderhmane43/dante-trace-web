import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomPriceForm extends StatelessWidget {
  final List<dynamic> customers;
  final List<dynamic> products;
  final int? selectedCustomerId;
  final int? selectedProductId;
  final double? originalPrice;
  final TextEditingController priceController;
  final bool isSaving;
  final ValueChanged<int?> onCustomerChanged;
  final ValueChanged<int?> onProductChanged;
  final VoidCallback onSave;

  const CustomPriceForm({
    super.key,
    required this.customers,
    required this.products,
    required this.selectedCustomerId,
    required this.selectedProductId,
    required this.originalPrice,
    required this.priceController,
    required this.isSaving,
    required this.onCustomerChanged,
    required this.onProductChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24), 
        // 🔥 تم إصلاح خطأ الـ Cascade (..) و الـ withValues
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 20, 
            offset: const Offset(0, 10)
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8), 
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)), 
                child: Icon(Icons.handshake_rounded, color: Colors.blue.shade700, size: 20)
              ),
              const SizedBox(width: 10),
              Text("تخصيص سعر لزبون (B2B)", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 20),
          
          // 1. القائمة المنسدلة للزبائن 👥 (تم تأمينها 100%)
          DropdownButtonFormField<int>(
            value: selectedCustomerId,
            decoration: InputDecoration(
              labelText: "اختر الزبون", 
              labelStyle: GoogleFonts.cairo(fontSize: 14),
              prefixIcon: const Icon(Icons.person_outline, color: Colors.blueGrey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15)
            ),
            items: customers.map<DropdownMenuItem<int>>((c) {
              // 🛡️ إجبار التحويل إلى int لمنع تضارب الأنواع
              final int cId = int.parse(c['id'].toString());
              final String cName = c['username']?.toString() ?? c['first_name']?.toString() ?? 'زبون غير معروف';
              
              return DropdownMenuItem<int>(
                value: cId, 
                child: Text(cName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold))
              );
            }).toList(),
            onChanged: onCustomerChanged,
          ),
          const SizedBox(height: 15),

          // 2. القائمة المنسدلة للمنتجات 📦 (تم تأمينها 100%)
          DropdownButtonFormField<int>(
            value: selectedProductId,
            decoration: InputDecoration(
              labelText: "اختر المنتج", 
              labelStyle: GoogleFonts.cairo(fontSize: 14),
              prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.blueGrey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15)
            ),
            items: products.map<DropdownMenuItem<int>>((p) {
              // 🛡️ إجبار التحويل إلى int
              final int pId = int.parse(p['id'].toString());
              final String pName = p['name']?.toString() ?? 'منتج غير معروف';

              return DropdownMenuItem<int>(
                value: pId, 
                child: Text(pName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold))
              );
            }).toList(),
            onChanged: onProductChanged,
          ),
          const SizedBox(height: 15),

          // عرض السعر الأصلي
          if (originalPrice != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Text("السعر الافتراضي للمنتج: $originalPrice دج", style: GoogleFonts.cairo(color: Colors.blueGrey.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 15),
          ],

          // 3. إدخال السعر الجديد المخصص 💰
          TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green.shade700),
            decoration: InputDecoration(
              labelText: "السعر المخفض للزبون (دج)", 
              labelStyle: GoogleFonts.cairo(fontSize: 14),
              prefixIcon: const Icon(Icons.local_offer_outlined, color: Colors.green),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.green.shade50,
            ),
          ),
          const SizedBox(height: 25),

          // 4. زر الحفظ ✅
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: isSaving ? null : onSave,
              icon: isSaving 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(
                isSaving ? "جاري الحفظ..." : "اعتماد السعر المخصص", 
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
              ),
            ),
          )
        ],
      ),
    );
  }
}