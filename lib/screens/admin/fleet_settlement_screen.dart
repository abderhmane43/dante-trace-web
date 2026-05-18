import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nfc_manager/nfc_manager.dart';

import '../../services/api_service.dart';

class FleetSettlementScreen extends StatefulWidget {
  const FleetSettlementScreen({super.key});

  @override
  State<FleetSettlementScreen> createState() => _FleetSettlementScreenState();
}

class _FleetSettlementScreenState extends State<FleetSettlementScreen> {
  final Color primaryBlue = const Color(0xFF1E293B);
  final Color successGreen = const Color(0xFF2E7D32);
  final Color bgGray = const Color(0xFFF8FAFC);

  bool _isLoading = true;
  List<dynamic> _fleetList = [];

  @override
  void initState() {
    super.initState();
    _fetchFleetData();
  }

  Future<void> _fetchFleetData() async {
    setState(() => _isLoading = true);
    try {
      final fleetData = await ApiService.getFleetStatus();
      if (mounted) {
        setState(() {
          // جلب فقط الموظفين الذين لديهم أموال أو طرود نشطة مغلقة معهم
          _fleetList = fleetData.where((driver) {
            double cash = double.tryParse(driver['current_cash_balance']?.toString() ?? '0') ?? 0.0;
            double check = double.tryParse(driver['current_check_balance']?.toString() ?? '0') ?? 0.0;
            return (cash > 0 || check > 0);
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showToast("حدث خطأ أثناء جلب البيانات", Colors.red);
      }
    }
  }

  void _showToast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  Future<void> _executeSettlement(String nfcId) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    try {
      final result = await ApiService.settleAccountWithAdmin(nfcId);
      if (mounted && Navigator.canPop(context)) Navigator.pop(context); // إغلاق التحميل
      
      if (result['status'] == 'success') {
        _showToast("✅ ${result['message']}", successGreen);
        _fetchFleetData(); // تحديث القائمة فوراً
      } else {
        _showToast("❌ ${result['message']}", Colors.red);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _showToast("❌ حدث خطأ أثناء التصفية", Colors.red);
    }
  }

  void _showSettlementOptions(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.account_balance_rounded, color: successGreen),
            const SizedBox(width: 10),
            Text("تصفية عهدة الموظف", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          "كيف تريد تصفية واستلام أموال (${driver['username']})؟",
          style: GoogleFonts.cairo(fontSize: 14),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: successGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
              icon: const Icon(Icons.nfc_rounded),
              label: Text("تصفية باللمس المباشر (NFC)", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.pop(ctx);
                if (kIsWeb) {
                  _showToast("NFC غير مدعوم في المتصفح. استخدم التصفية اليدوية.", Colors.orange.shade800);
                  return;
                }
                
                bool isAvailable = await NfcManager.instance.isAvailable();
                if (!isAvailable) {
                  _showToast("حساس NFC غير مفعل في هاتفك", Colors.red);
                  return;
                }
                
                showDialog(
                  context: context, barrierDismissible: false,
                  builder: (c) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.contactless_rounded, size: 80, color: successGreen),
                        const SizedBox(height: 15),
                        Text("يرجى تمرير بطاقة الموظف لتأكيد التصفية", textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        TextButton(onPressed: () { NfcManager.instance.stopSession(); Navigator.pop(c); }, child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.red)))
                      ],
                    ),
                  )
                );

                NfcManager.instance.startSession(
                  pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
                  onDiscovered: (NfcTag tag) async {
                    NfcManager.instance.stopSession();
                    if (!mounted) return;
                    Navigator.pop(context); // إغلاق نافذة القراءة
                    
                    List<int>? identifier;
                    try {
                      final Map<dynamic, dynamic> rawTagData = (tag as dynamic).data as Map<dynamic, dynamic>;
                      for (var value in rawTagData.values) {
                        if (value is Map && value.containsKey('identifier')) {
                          var rawId = value['identifier'];
                          if (rawId is List) {
                            identifier = rawId.map((e) => int.parse(e.toString())).toList();
                            break;
                          }
                        }
                      }
                    } catch(e) {}

                    if (identifier != null && identifier.isNotEmpty) {
                      String scannedNfcId = identifier.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
                      _executeSettlement(scannedNfcId);
                    } else {
                      _showToast("❌ تعذر قراءة البطاقة", Colors.red);
                    }
                  }
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: primaryBlue, side: BorderSide(color: primaryBlue), padding: const EdgeInsets.symmetric(vertical: 12)),
              icon: const Icon(Icons.touch_app_rounded),
              label: Text("تصفية يدوية (عن بُعد)", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                String? storedNfc = driver['driver_nfc_id'];
                if (storedNfc != null && storedNfc.isNotEmpty) {
                  _executeSettlement(storedNfc); // التصفية عبر الكود المخزن في قاعدة البيانات
                } else {
                  _showToast("❌ الموظف لا يمتلك بطاقة مسجلة في النظام لتصفيته يدوياً", Colors.red);
                }
              },
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey)))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGray,
      appBar: AppBar(
        title: Text("تصفية ومراجعة عهدة الأسطول", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: primaryBlue,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
        ? _buildShimmer() 
        : _fleetList.isEmpty 
          ? Center(child: Text("لا يوجد موظفون لديهم عهدة مالية حالياً.", style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey)))
          : RefreshIndicator(
              onRefresh: _fetchFleetData,
              color: primaryBlue,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _fleetList.length,
                itemBuilder: (ctx, index) {
                  final driver = _fleetList[index];
                  double cash = double.tryParse(driver['current_cash_balance']?.toString() ?? '0') ?? 0.0;
                  double check = double.tryParse(driver['current_check_balance']?.toString() ?? '0') ?? 0.0;
                  double total = cash + check;

                  List<dynamic> activeOrders = driver['active_orders'] ?? [];

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
                    child: ExpansionTile(
                      shape: const Border(),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: Icon(Icons.person, color: Colors.orange.shade800)),
                      title: Text(driver['username'], style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text("إجمالي العهدة: ${NumberFormat('#,##0.00').format(total)} دج", style: GoogleFonts.poppins(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
                      children: [
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("الطلبيات المسجلة في العهدة:", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                              const SizedBox(height: 10),
                              if (activeOrders.isEmpty)
                                Text("العهدة ناتجة عن تحصيلات سابقة أو مصاريف.", style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                              ...activeOrders.map((o) {
                                double oAmount = double.tryParse(o['cash_amount']?.toString() ?? '0') ?? 0.0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      Icon(Icons.inventory_2_rounded, size: 14, color: primaryBlue),
                                      const SizedBox(width: 5),
                                      Expanded(child: Text("${o['customer_name']} (${o['tracking_number']})", style: GoogleFonts.cairo(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                      Text("${NumberFormat('#,##0').format(oAmount)} دج", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 15),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: successGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  onPressed: () => _showSettlementOptions(driver),
                                  icon: const Icon(Icons.monetization_on_rounded, size: 18),
                                  label: Text("تصفية واستلام الخزينة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      itemBuilder: (ctx, i) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200, highlightColor: Colors.white,
        child: Container(height: 100, margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
      )
    );
  }
}