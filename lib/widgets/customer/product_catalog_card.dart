import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // 🔥 استيراد مكتبة التنسيق المالي

class ProductCatalogCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final int currentQty;
  final Color pColor;
  final IconData pIcon;
  final VoidCallback onAddQty;
  final VoidCallback onRemoveQty;
  final VoidCallback onEditQty; // هذه هي الدالة السحرية التي ستفتح الكيبورد
  final VoidCallback onAddToCart;

  const ProductCatalogCard({
    super.key,
    required this.product,
    required this.currentQty,
    required this.pColor,
    required this.pIcon,
    required this.onAddQty,
    required this.onRemoveQty,
    required this.onEditQty,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    // 🔥 التنسيق المالي لسعر المنتج
    final double rawPrice = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
    final String formattedPrice = NumberFormat('#,##0.00').format(rawPrice);

    return Container(
      width: 170,
      margin: const EdgeInsets.only(left: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 📦 أيقونة واسم المنتج
          Padding(
            padding: const EdgeInsets.only(top: 15.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: pColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(pIcon, size: 35, color: pColor),
                ),
                const SizedBox(height: 10),
                Text(
                  product['name'],
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "$formattedPrice دج", // 🔥 تم تطبيق التنسيق الجديد هنا
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 13),
                ),
              ],
            ),
          ),

          // 🔢 أزرار التحكم بالكمية + إدخال الكيبورد
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // زر الناقص (-)
                InkWell(
                  onTap: onRemoveQty,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.remove, size: 18),
                  ),
                ),
                
                // 🔥 الرقم القابل للضغط لفتح الكيبورد
                Expanded(
                  child: GestureDetector(
                    onTap: onEditQty, // عند الضغط على الرقم، تفتح نافذة إدخال الكمية
                    child: Container(
                      color: Colors.transparent, // لضمان استجابة كامل المنطقة للضغط
                      child: Text(
                        "$currentQty",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900),
                      ),
                    ),
                  ),
                ),
                
                // زر الزائد (+)
                InkWell(
                  onTap: onAddQty,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.add, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // 🛒 زر الإضافة للسلة
          InkWell(
            onTap: onAddToCart,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: pColor,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 22),
            ),
          )
        ],
      ),
    );
  }
}