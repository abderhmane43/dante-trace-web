import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplitOrderDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final Function(Map<String, dynamic> splitData) onConfirm;

  const SplitOrderDialog({super.key, required this.order, required this.onConfirm});

  @override
  State<SplitOrderDialog> createState() => _SplitOrderDialogState();
}

class _SplitOrderDialogState extends State<SplitOrderDialog> {
  Map<int, int> splitQuantities = {};
  bool isProcessing = false;
  late List<dynamic> items;

  @override
  void initState() {
    super.initState();
    items = List.from(widget.order['items'] ?? []);
    for (int i = 0; i < items.length; i++) {
      splitQuantities[i] = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    double originalCashRemaining = 0;
    double newOrderCash = 0;

    for (int i = 0; i < items.length; i++) {
      int originalQty = items[i]['qty'];
      int movingQty = splitQuantities[i]!;
      double price = (items[i]['price'] ?? 0).toDouble();
      newOrderCash += (price * movingQty);
      originalCashRemaining += (price * (originalQty - movingQty));
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        const Icon(Icons.call_split_rounded, color: Colors.deepPurple),
        const SizedBox(width: 10),
        Text("تقسيم الطلبية", style: GoogleFonts.cairo(fontWeight: FontWeight.bold))
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(items.length, (index) {
                final item = items[index];
                return Card(
                  color: Colors.grey.shade50,
                  child: ListTile(
                    title: Text(item['name'], style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text("الكمية: ${item['qty']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: splitQuantities[index]! > 0 ? () => setState(() => splitQuantities[index] = splitQuantities[index]! - 1) : null),
                        Text("${splitQuantities[index]}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: splitQuantities[index]! < item['qty'] ? () => setState(() => splitQuantities[index] = splitQuantities[index]! + 1) : null),
                      ],
                    ),
                  ),
                );
              }),
              const Divider(),
              Text("جديد: $newOrderCash دج", style: GoogleFonts.cairo(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
        ElevatedButton(
          onPressed: isProcessing ? null : () {
            // هنا نجهز البيانات ونرسلها للدالة Confirm
            List<Map<String, dynamic>> splitItems = [];
            List<Map<String, dynamic>> remainingItems = [];
            for (int i = 0; i < items.length; i++) {
               if (splitQuantities[i]! > 0) splitItems.add({"name": items[i]['name'], "price": items[i]['price'], "qty": splitQuantities[i]});
               if (items[i]['qty'] - splitQuantities[i]! > 0) remainingItems.add({"name": items[i]['name'], "price": items[i]['price'], "qty": items[i]['qty'] - splitQuantities[i]!});
            }
            widget.onConfirm({
              "split_items": splitItems,
              "new_cash": newOrderCash,
              "remaining_items": remainingItems,
              "remaining_cash": originalCashRemaining
            });
          },
          child: const Text("تأكيد الشطر"),
        )
      ],
    );
  }
}