import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductsListTab extends StatelessWidget {
  final bool isLoading;
  final List<dynamic> productsList;
  final Future<void> Function() onRefresh;
  final Function(int productId, String productName) onDeleteProduct;

  const ProductsListTab({
    super.key,
    required this.isLoading,
    required this.productsList,
    required this.onRefresh,
    required this.onDeleteProduct,
  });

  final Color primaryIndigo = const Color(0xFF283593); // Colors.indigo.shade800

  IconData _getIconFromName(String name) {
    switch (name.toLowerCase()) {
      case 'videocam': return Icons.videocam_rounded;
      case 'nfc': return Icons.nfc_rounded;
      case 'location': return Icons.location_on_rounded;
      case 'tablet': return Icons.tablet_mac_rounded;
      default: return Icons.inventory_2_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryIndigo));
    }

    if (productsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 15),
            Text("لا توجد منتجات مسجلة حالياً", style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey))
          ],
        )
      );
    }

    return RefreshIndicator(
      color: primaryIndigo,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: productsList.length,
        itemBuilder: (context, index) {
          final product = productsList[index];
          final pIcon = _getIconFromName(product['icon'] ?? product['icon_name'] ?? 'videocam');

          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            margin: const EdgeInsets.only(bottom: 15),
            child: ListTile(
              contentPadding: const EdgeInsets.all(15),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: primaryIndigo..withValues(alpha:0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(pIcon, color: primaryIndigo),
              ),
              title: Text(product['name'] ?? 'منتج', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text(
                "ID: ${product['id']} | السعر: ${product['base_price'] ?? product['price']} دج",
                style: GoogleFonts.cairo(color: Colors.green.shade700, fontWeight: FontWeight.bold, height: 1.5, fontSize: 13),
              ),
              trailing: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red)
                ),
                onPressed: () => onDeleteProduct(product['id'], product['name']),
              ),
            ),
          );
        },
      ),
    );
  }
}