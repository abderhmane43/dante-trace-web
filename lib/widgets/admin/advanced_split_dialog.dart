import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

// ============================================================================
// 🔥 كلاس "المخطط اللوجستي" للتجزئة المتعددة (بالكميات والقطع) المفضل
// ============================================================================
class AdvancedSplitDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final Function(String whatsappMsg, String phone) onSuccess;
  final VoidCallback onError;

  const AdvancedSplitDialog({super.key, required this.order, required this.onSuccess, required this.onError});

  @override
  State<AdvancedSplitDialog> createState() => _AdvancedSplitDialogState();
}

class _AdvancedSplitDialogState extends State<AdvancedSplitDialog> {
  final Color pendingPurple = const Color(0xFF9C27B0); 
  final Color darkBlue = const Color(0xFF1E293B); 
  
  late List<Map<String, dynamic>> _remainingItems;
  late double _originalTotalCash;

  List<Map<String, dynamic>> _batches = [];
  
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    
    List<dynamic> rawItems = [];
    dynamic itemsData = widget.order['total_remaining_items'] ?? widget.order['items'];

    if (itemsData is String) {
      try {
        rawItems = jsonDecode(itemsData);
      } catch (e) {
        debugPrint("خطأ في قراءة المنتجات من JSON: $e");
      }
    } else if (itemsData is List) {
      rawItems = itemsData;
    }

    _remainingItems = rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _originalTotalCash = double.tryParse(widget.order['cash_amount']?.toString() ?? '0') ?? 0.0;
    
    _addNewBatch();
  }

  void _addNewBatch() {
    String randomSuffix = DateTime.now().millisecondsSinceEpoch.toString().substring(9);
    String newTracking = "${widget.order['tracking_number']}-B${_batches.length + 1}-$randomSuffix";
    
    Map<String, int> initialSelection = {};
    for (var item in _remainingItems) {
      initialSelection[item['name']] = 0; 
    }

    setState(() {
      _batches.add({
        "tracking": newTracking,
        "selected_quantities": initialSelection,
        "date": null,
        "require_approval": false, // 🔥 تم التعديل لتكون غير مفعلة افتراضياً
      });
    });
  }

  void _removeBatch(int index) {
    setState(() {
      _batches.removeAt(index);
    });
  }

  int _calculateRealRemainingQty(String itemName) {
    int originalQty = _remainingItems.firstWhere((i) => i['name'] == itemName, orElse: () => {'qty': 0})['qty'];
    int totalSelectedInBatches = 0;
    for (var batch in _batches) {
      totalSelectedInBatches += (batch['selected_quantities'][itemName] as int? ?? 0);
    }
    return originalQty - totalSelectedInBatches;
  }

  double _calculateBatchCash(Map<String, dynamic> batch) {
    double total = 0;
    for (var item in _remainingItems) {
      int selectedQty = batch['selected_quantities'][item['name']] ?? 0;
      double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      total += selectedQty * price;
    }
    return total;
  }

  double _calculateTotalRemainingCash() {
    double totalAllocated = 0;
    for (var batch in _batches) {
      totalAllocated += _calculateBatchCash(batch);
    }
    if (_remainingItems.isEmpty) return _originalTotalCash; 
    return _originalTotalCash - totalAllocated;
  }

  // 🔥 دالة الإدخال اليدوي المباشر للكميات لتوفير الوقت
  void _showQuantityInputDialog(Map<String, dynamic> batch, String itemName, int currentQty, int maxCanSelect) {
    TextEditingController qtyCtrl = TextEditingController(text: currentQty.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("إدخال الكمية: $itemName", style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: pendingPurple, foregroundColor: Colors.white),
            onPressed: () {
              int? val = int.tryParse(qtyCtrl.text);
              if (val != null) {
                if (val < 0) val = 0;
                if (val > maxCanSelect) val = maxCanSelect; // حماية من تجاوز الكمية المتوفرة
                setState(() => batch['selected_quantities'][itemName] = val);
              }
              Navigator.pop(ctx);
            },
            child: Text("اعتماد", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _submitAdvancedSplit() async {
    if (_batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يجب إنشاء دفعة واحدة على الأقل.")));
      return;
    }

    if (_remainingItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("لا يمكن تقسيم طلبية لا تحتوي على تفاصيل منتجات (قطع).", style: GoogleFonts.cairo()), backgroundColor: Colors.red));
      return;
    }

    List<Map<String, dynamic>> finalBatchesToSubmit = [];
    String whatsappSummary = "مرحباً ${widget.order['customer_name']} 👋\n\nتمت جدولة طلبيتك بنجاح على الدفعات التالية 📦:\n\n";

    for (int i = 0; i < _batches.length; i++) {
      var batch = _batches[i];
      
      if (batch['date'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("الدفعة ${i+1} تفتقر لتحديد التاريخ!")));
        return;
      }

      int totalItemsInThisBatch = 0;
      List<Map<String, dynamic>> batchItemsList = [];
      String itemsDetailString = ""; 

      batch['selected_quantities'].forEach((name, qty) {
        if (qty > 0) {
          totalItemsInThisBatch += qty as int;
          double price = double.tryParse(_remainingItems.firstWhere((item) => item['name'] == name)['price'].toString()) ?? 0;
          batchItemsList.add({"name": name, "qty": qty, "price": price});
          
          itemsDetailString += "   ▪️ $qty x $name\n";
        }
      });

      if (totalItemsInThisBatch == 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("لم تقم بتحديد أي قطع للدفعة رقم ${i+1}!")));
        return;
      }

      double finalBatchCash = _calculateBatchCash(batch);
      String formattedBatchCashMsg = NumberFormat('#,##0.00').format(finalBatchCash);
      String dateFormatted = DateFormat('yyyy-MM-dd HH:mm').format(batch['date']);

      finalBatchesToSubmit.add({
        "new_tracking_number": batch['tracking'],
        "split_items": batchItemsList,
        "split_cash_amount": finalBatchCash,
        "scheduled_date": batch['date'].toIso8601String(),
        "require_customer_approval": batch['require_approval']
      });

      whatsappSummary += "📌 الدفعة رقم ${i+1}:\n";
      whatsappSummary += "📦 المنتجات:\n$itemsDetailString";
      whatsappSummary += "💰 المبلغ الإجمالي: $formattedBatchCashMsg دج\n";
      whatsappSummary += "⏰ موعد الاستلام: $dateFormatted\n";
      whatsappSummary += "〰️〰️〰️〰️\n";
    }

    List<Map<String, dynamic>> finalRemainingItemsToSave = [];
    for (var item in _remainingItems) {
      int rQty = _calculateRealRemainingQty(item['name']);
      if (rQty > 0) {
        finalRemainingItemsToSave.add({"name": item['name'], "qty": rQty, "price": item['price']});
      }
    }

    whatsappSummary += "\nيرجى مراجعة تطبيقك لتأكيد المواعيد.\nشكراً لثقتكم بنا! 🚚";

    Map<String, dynamic> advancedData = {
      "master_shipment_id": widget.order['id'],
      "batches": finalBatchesToSubmit,
      "remaining_items_in_master": finalRemainingItemsToSave,
      "remaining_cash_in_master": _calculateTotalRemainingCash()
    };

    setState(() => _isProcessing = true);

    bool success = await ApiService.splitShipment(advancedData);

    if (!mounted) return;
    Navigator.pop(context); 

    if (success) {
      widget.onSuccess(whatsappSummary, widget.order['customer_phone']?.toString() ?? '');
    } else {
      widget.onError();
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalRemainingCash = _calculateTotalRemainingCash();
    final String formattedRemainingCash = NumberFormat('#,##0.00').format(totalRemainingCash);

    int totalRemainingItems = 0;
    for (var item in _remainingItems) {
      totalRemainingItems += _calculateRealRemainingQty(item['name']);
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFF8FAFC),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: pendingPurple, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Row(
          children: [
            const Icon(Icons.account_tree_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text("المخطط اللوجستي (تجزئة القطع)", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white))),
            IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints())
          ],
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isProcessing 
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.account_balance_wallet_rounded, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 5),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("المبلغ المتبقي:", style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade600)),
                                  Text("$formattedRemainingCash دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: totalRemainingCash < 0 ? Colors.red : Colors.green.shade700, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 16, color: darkBlue),
                              const SizedBox(width: 5),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("القطع المتبقية:", style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade600)),
                                  Text("$totalRemainingItems قطعة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: totalRemainingItems == 0 ? Colors.red : darkBlue, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 15),
                      Text("📦 تفاصيل القطع المتوفرة:", style: GoogleFonts.cairo(fontSize: 12, color: darkBlue, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _remainingItems.isEmpty 
                        ? Text("⚠️ هذه الطلبية لا تحتوي على تفاصيل منتجات لتقسيمها!", style: GoogleFonts.cairo(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))
                        : Wrap(
                            spacing: 8, runSpacing: 8,
                            children: _remainingItems.map((item) {
                              int currentRemaining = _calculateRealRemainingQty(item['name']);
                              return Chip(
                                label: Text("${item['name']}: $currentRemaining", style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: currentRemaining == 0 ? Colors.red : Colors.black)),
                                backgroundColor: currentRemaining == 0 ? Colors.red.shade50 : Colors.blue.shade50,
                                side: BorderSide.none, padding: EdgeInsets.zero,
                              );
                            }).toList(),
                          )
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _batches.length,
                    itemBuilder: (ctx, index) => _buildBatchCard(index),
                  ),
                ),

                const SizedBox(height: 10),
                if (_remainingItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: _addNewBatch,
                    icon: const Icon(Icons.add_box_rounded),
                    label: Text("إضافة دفعة جديدة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(foregroundColor: pendingPurple),
                  )
              ],
            ),
      ),
      actions: [
        if (!_isProcessing)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: pendingPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _submitAdvancedSplit,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: Text("اعتماد الجدولة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          )
      ],
    );
  }

  Widget _buildBatchCard(int index) {
    var batch = _batches[index];
    double batchCash = _calculateBatchCash(batch);
    final String formattedBatchCash = NumberFormat('#,##0.00').format(batchCash);
    
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: pendingPurple.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("الدفعة ${index + 1}", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: pendingPurple, fontSize: 14)),
                if (_batches.length > 1)
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _removeBatch(index), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            ),
            const Divider(),
            
            if (_remainingItems.isNotEmpty) ...[
              Text("اختر القطع لهذه الدفعة:", style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 5),
              ..._remainingItems.map((item) {
                String name = item['name'];
                int mySelectedQty = batch['selected_quantities'][name] ?? 0;
                int maxCanSelect = mySelectedQty + _calculateRealRemainingQty(name);

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Expanded(child: Text(name, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Row(
                        children: [
                          InkWell(
                            onTap: mySelectedQty > 0 ? () => setState(() => batch['selected_quantities'][name] = mySelectedQty - 1) : null,
                            child: Icon(Icons.remove_circle, color: mySelectedQty > 0 ? Colors.red.shade400 : Colors.grey.shade300, size: 28),
                          ),
                          const SizedBox(width: 8),
                          // 🔥 تحويل الرقم إلى زر يفتح لوحة إدخال الأرقام
                          InkWell(
                            onTap: () => _showQuantityInputDialog(batch, name, mySelectedQty, maxCanSelect),
                            child: Container(
                              width: 50, alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: pendingPurple.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(6)
                              ),
                              child: Text("$mySelectedQty", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: mySelectedQty < maxCanSelect ? () => setState(() => batch['selected_quantities'][name] = mySelectedQty + 1) : null,
                            child: Icon(Icons.add_circle, color: mySelectedQty < maxCanSelect ? Colors.green.shade500 : Colors.grey.shade300, size: 28),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              }),
            ],
            
            const SizedBox(height: 10),

            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: batch['require_approval'] ? pendingPurple.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: batch['require_approval'] ? pendingPurple.withOpacity(0.3) : Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        batch['require_approval'] ? Icons.verified_user_rounded : Icons.offline_bolt_rounded,
                        size: 18,
                        color: batch['require_approval'] ? pendingPurple : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        batch['require_approval'] ? "يتطلب موافقة الزبون" : "نقل تلقائي (بدون موافقة)",
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: batch['require_approval'] ? pendingPurple : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: batch['require_approval'],
                    activeColor: pendingPurple,
                    onChanged: (bool value) {
                      setState(() {
                        batch['require_approval'] = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime(2030));
                      if (pickedDate != null) {
                        if (!context.mounted) return;
                        TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
                        if (pickedTime != null) {
                          setState(() => batch['date'] = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute));
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month, size: 16, color: batch['date'] == null ? Colors.grey : darkBlue),
                          const SizedBox(width: 5),
                          Text(batch['date'] == null ? "تحديد الموعد" : DateFormat('MM-dd HH:mm').format(batch['date']), style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: batch['date'] == null ? Colors.grey : darkBlue)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                  child: Row(
                    children: [
                      const Icon(Icons.payments_outlined, size: 16, color: Colors.green),
                      const SizedBox(width: 5),
                      Text("$formattedBatchCash دج", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                    ],
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}