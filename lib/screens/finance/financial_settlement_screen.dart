import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد فحص الويب
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:intl/intl.dart'; 

import '../../services/api_service.dart';

class FinancialSettlementScreen extends StatefulWidget {
  const FinancialSettlementScreen({super.key});

  @override
  State<FinancialSettlementScreen> createState() => _FinancialSettlementScreenState();
}

class _FinancialSettlementScreenState extends State<FinancialSettlementScreen> {
  final Color primaryRed = const Color(0xFFB71C1C);
  final Color successGreen = const Color(0xFF1B5E20);
  final Color backgroundGray = const Color(0xFFF4F7F9);
  final Color darkBlue = const Color(0xFF1E293B);

  bool _isLoading = true;
  List<dynamic> _usersWithBalance = [];
  List<dynamic> _allShipments = []; 
  
  double _totalExpectedCash = 0.0;
  double _totalExpectedCheck = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchBalancesAndOrders();
  }

  // ==========================================
  // 📥 جلب البيانات الآمن (الموظفين + الطرود)
  // ==========================================
  Future<void> _fetchBalancesAndOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=utf-8'
      };

      final results = await Future.wait([
        http.get(Uri.parse('${ApiService.baseUrl}/users/'), headers: headers).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('${ApiService.baseUrl}/admin/all-orders'), headers: headers).timeout(const Duration(seconds: 15)),
      ]);

      if (results[0].statusCode == 200) {
        final List<dynamic> allUsers = jsonDecode(utf8.decode(results[0].bodyBytes));
        
        if (results[1].statusCode == 200) {
          _allShipments = jsonDecode(utf8.decode(results[1].bodyBytes));
        }

        List<dynamic> debtors = [];
        double runningTotalCash = 0.0;
        double runningTotalCheck = 0.0;

        for (var user in allUsers) {
          final role = user['role']?.toString().toLowerCase() ?? '';
          final bool isFieldWorker = role == 'driver' || role == 'collector';
          
          final double cashBalance = double.tryParse(user['current_cash_balance']?.toString() ?? '0.0') ?? 0.0;
          final double checkBalance = double.tryParse(user['current_check_balance']?.toString() ?? '0.0') ?? 0.0; 
          
          if (isFieldWorker && (cashBalance > 0 || checkBalance > 0)) {
            debtors.add(user);
            runningTotalCash += cashBalance;
            runningTotalCheck += checkBalance;
          }
        }

        if (mounted) {
          setState(() {
            _usersWithBalance = debtors;
            _totalExpectedCash = runningTotalCash;
            _totalExpectedCheck = runningTotalCheck;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        _showToast("حدث خطأ في الخادم", Colors.red);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showToast("تعذر الاتصال بالسيرفر", Colors.orange.shade900);
    }
  }

  // ==========================================
  // 📋 نافذة التفاصيل (محدثة بخيارين: NFC + يدوي) 🔥
  // ==========================================
  void _showSettlementDetails(Map<String, dynamic> user) {
    final bool isDriver = user['role'] == 'driver';
    final int userId = user['id'];
    final String name = (user['first_name']?.toString().isNotEmpty == true) ? user['first_name'].toString() : user['username'].toString();
    
    // 🔥 تنسيق عهدة الموظف
    final double cashBalance = double.tryParse(user['current_cash_balance']?.toString() ?? '0.0') ?? 0.0;
    final double checkBalance = double.tryParse(user['current_check_balance']?.toString() ?? '0.0') ?? 0.0;
    
    final String formattedCash = NumberFormat('#,##0.00').format(cashBalance);
    final String formattedCheck = NumberFormat('#,##0.00').format(checkBalance);

    final List<dynamic> userOrders = _allShipments.where((order) {
      if (isDriver) {
        return order['driver_id'] == userId && order['delivery_status'] == 'delivered';
      } else {
        return order['delivery_status'] == 'settled_with_collector';
      }
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 🔥 شفاف لدعم الويب
      builder: (bottomSheetCtx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600), // 🔥 تقييد العرض في الكمبيوتر
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  
                  // رأس النافذة (معلومات الموظف)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("مراجعة العهدة المالية", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                            Text("الموظف: $name", style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 15),
                  // 🔥 تفاصيل المبالغ
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                          child: Column(
                            children: [
                              Text("كاش 💵", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                              Text("$formattedCash دج", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purple.shade200)),
                          child: Column(
                            children: [
                              Text("شيكات 📄", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade800)),
                              Text("$formattedCheck دج", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple.shade900)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const Divider(height: 30),
                  
                  Text("📋 تفاصيل الطرود المُحصّلة:", style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: darkBlue)),
                  const SizedBox(height: 10),
                  
                  Expanded(
                    child: userOrders.isEmpty
                        ? Center(child: Text("لم يتم العثور على تفاصيل مفصلة للطرود، قد يكون المبلغ من تسويات سابقة.", textAlign: TextAlign.center, style: GoogleFonts.cairo(color: Colors.grey)))
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: userOrders.length,
                            itemBuilder: (ctx, idx) {
                              final order = userOrders[idx];
                              final List<dynamic> items = order['items'] ?? []; 
                              
                              final double orderAmount = double.tryParse(order['cash_amount']?.toString() ?? '0') ?? 0.0;
                              final String formattedOrderAmount = NumberFormat('#,##0.00').format(orderAmount);

                              return Card(
                                elevation: 0,
                                color: Colors.grey.shade50,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(backgroundColor: Colors.blue.shade50, radius: 18, child: const Icon(Icons.inventory_2_rounded, color: Colors.blue, size: 18)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(order['customer_name'] ?? 'زبون', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: darkBlue)),
                                                Text("T: ${order['tracking_number']}", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                                              ],
                                            ),
                                          ),
                                          Text("$formattedOrderAmount دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: successGreen, fontSize: 15)),
                                        ],
                                      ),
                                      
                                      if (items.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: items.map((item) {
                                              final String itemName = item['name']?.toString() ?? 'قطعة';
                                              final int qty = item['qty'] ?? 1;
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 4),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.stop_rounded, size: 8, color: Colors.grey.shade400),
                                                    const SizedBox(width: 6),
                                                    Expanded(child: Text(itemName, style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade700))),
                                                    Text("× $qty", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        )
                                      ]
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // 🔥 الزر الأول: التصفية الأساسية بالـ NFC
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () {
                        _startNfcSettlement(user, onSuccess: () {
                          if (bottomSheetCtx.mounted && Navigator.canPop(bottomSheetCtx)) {
                            Navigator.pop(bottomSheetCtx); 
                          }
                        });
                      },
                      icon: const Icon(Icons.nfc_rounded, size: 24),
                      label: Text("تأكيد التصفية عبر NFC", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // 🔥 الزر الثاني: التصفية اليدوية (صلاحية الإدارة)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(color: Colors.orange.shade300, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () => _confirmManualSettlement(user, bottomSheetCtx),
                      icon: const Icon(Icons.fact_check_rounded, size: 20),
                      label: Text("تأكيد التصفية يدوياً (الخطة البديلة)", style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 🛡️ التصفية اليدوية (بدون NFC)
  // ==========================================
  void _confirmManualSettlement(Map<String, dynamic> user, BuildContext bottomSheetCtx) {
    final String name = (user['first_name']?.toString().isNotEmpty == true) ? user['first_name'].toString() : user['username'].toString();
    
    final double cash = double.tryParse(user['current_cash_balance']?.toString() ?? '0.0') ?? 0.0;
    final double check = double.tryParse(user['current_check_balance']?.toString() ?? '0.0') ?? 0.0;
    final String formattedCash = NumberFormat('#,##0.00').format(cash);
    final String formattedCheck = NumberFormat('#,##0.00').format(check);
    
    // نأخذ كود البطاقة المسجل لتمريره كأنه تم مسحه
    final String expectedNfc = (user['driver_nfc_id']?.toString() ?? '').replaceAll(':', '').toUpperCase().trim();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Text("تأكيد التصفية اليدوية", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          "هل أنت متأكد من استلامك للعهدة ($formattedCash دج كاش + $formattedCheck دج شيكات) من الموظف ($name) يدوياً وبدون استخدام بطاقة الـ NFC؟",
          style: GoogleFonts.cairo(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("تراجع", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx); // إغلاق نافذة التأكيد
              
              if (expectedNfc.isEmpty) {
                _showToast("هذا الموظف ليس لديه بطاقة NFC مسجلة في النظام لتخطيها!", Colors.red);
                return;
              }

              _showLoadingOverlay();
              
              // محاكاة إرسال كود الـ NFC للسيرفر مباشرة من الإدارة لتصفية الحساب
              final result = await ApiService.settleDriverAccount(expectedNfc);
              
              if (mounted) Navigator.pop(context); // إغلاق الـ Loading

              if (result['success'] == true) {
                _showToast("تمت التصفية اليدوية بنجاح وتم إبراء الذمة!", successGreen);
                _fetchBalancesAndOrders(); 
                if (bottomSheetCtx.mounted && Navigator.canPop(bottomSheetCtx)) {
                  Navigator.pop(bottomSheetCtx); 
                }
              } else {
                _showToast(result['message'], Colors.red);
              }
            },
            child: Text("نعم، استلمت المبالغ", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🤝 تصفية الحسابات (NFC Engine Pro)
  // ==========================================
  Future<void> _startNfcSettlement(Map<String, dynamic> user, {VoidCallback? onSuccess}) async {
    // 🔥 الحماية من الويب: الـ NFC يعمل فقط على تطبيق الهاتف
    if (kIsWeb) {
      _showToast("خاصية مسح الـ NFC غير مدعومة في متصفح الويب. الرجاء استخدام (التصفية اليدوية).", Colors.orange.shade800);
      return;
    }

    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        _showToast("حساس NFC غير متوفر أو معطل!", Colors.red);
        return;
      }

      final String name = (user['first_name']?.toString().isNotEmpty == true) ? user['first_name'].toString() : user['username'].toString();
      final String expectedNfc = (user['driver_nfc_id']?.toString() ?? '').replaceAll(':', '').toUpperCase().trim();
      
      // 🔥 تنسيق المبلغ للشاشة المنبثقة
      final double cash = double.tryParse(user['current_cash_balance']?.toString() ?? '0.0') ?? 0.0;
      final double check = double.tryParse(user['current_check_balance']?.toString() ?? '0.0') ?? 0.0;
      final String formattedCash = NumberFormat('#,##0.00').format(cash);
      final String formattedCheck = NumberFormat('#,##0.00').format(check);

      if (expectedNfc.isEmpty) {
        _showToast("لا توجد بطاقة مسجلة لهذا الموظف!", Colors.orange.shade900);
        return;
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isDismissible: false,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.nfc_rounded, size: 50, color: Colors.blue),
              ),
              const SizedBox(height: 15),
              Text("استلام عهدة: $name", style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
              
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text("كاش 💵", style: GoogleFonts.cairo(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                      Text("$formattedCash دج", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.green.shade700)),
                    ],
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  Column(
                    children: [
                      Text("شيكات 📄", style: GoogleFonts.cairo(fontSize: 12, color: Colors.purple.shade800, fontWeight: FontWeight.bold)),
                      Text("$formattedCheck دج", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.purple.shade700)),
                    ],
                  )
                ],
              ),
              
              const SizedBox(height: 20),
              Text("مرر بطاقة الموظف خلف الهاتف لتأكيد التصفية", style: GoogleFonts.cairo(color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () { 
                  NfcManager.instance.stopSession(); 
                  Navigator.pop(ctx); 
                },
                child: Text("إلغاء العملية", style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      );

      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
        onDiscovered: (NfcTag tag) async {
          NfcManager.instance.stopSession();
          if (mounted && Navigator.canPop(context)) Navigator.pop(context); 

          List<int>? identifier;
          try {
            // 🛡️ الحل الجذري لتخطي حماية الدارت في الـ NFC (هنا كان الخطأ وتم إصلاحه)
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
          } catch(e) {
            debugPrint("NFC Read Error: $e");
          }

          if (identifier != null && identifier.isNotEmpty) {
            String scannedId = identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();

            if (scannedId != expectedNfc) {
              _showToast("البطاقة غير متطابقة مع الموظف المختار!", Colors.red);
              return;
            }

            _showLoadingOverlay();
            final result = await ApiService.settleDriverAccount(scannedId);
            if (mounted) Navigator.pop(context); 

            if (result['success'] == true) {
              _showToast("تمت التصفية بنجاح وتم إبراء الذمة!", successGreen);
              _fetchBalancesAndOrders(); 
              if (onSuccess != null) onSuccess(); 
            } else {
              _showToast(result['message'], Colors.red);
            }
          } else {
            _showToast("لم نتمكن من قراءة الشريحة بشكل صحيح.", Colors.orange.shade800);
          }
        }
      );
    } catch (e) {
      _showToast("حدث خطأ غير متوقع في حساس الـ NFC", Colors.red);
    }
  }

  // ==========================================
  // 🖥️ بناء الواجهة الرئيسية
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGray,
      appBar: AppBar(
        title: Text("الخزينة والتسوية", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchBalancesAndOrders)],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)))
        : RefreshIndicator(
            onRefresh: _fetchBalancesAndOrders,
            color: primaryRed,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _usersWithBalance.isEmpty ? 3 : _usersWithBalance.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) return _buildVaultCard();
                if (index == 1) return _buildListTitle();
                if (_usersWithBalance.isEmpty && index == 2) return _buildEmptyState();
                
                final user = _usersWithBalance[index - 2];
                return _buildDriverCard(user);
              },
            ),
          ),
    );
  }

  Widget _buildVaultCard() {
    // 🔥 تنسيق إجمالي الخزينة المنتظر للكاش وللشيكات ليظهر في البطاقة الخضراء العلوية
    final String formattedExpectedCash = NumberFormat('#,##0.00').format(_totalExpectedCash);
    final String formattedExpectedCheck = NumberFormat('#,##0.00').format(_totalExpectedCheck);

    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: successGreen, 
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text("إجمالي المبالغ المنتظر استلامها", style: GoogleFonts.cairo(color: Colors.white, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text("كاش 💵", style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13)),
                    FittedBox(
                      child: Text(
                        "$formattedExpectedCash", 
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white30),
              Expanded(
                child: Column(
                  children: [
                    Text("شيكات 📄", style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13)),
                    FittedBox(
                      child: Text(
                        "$formattedExpectedCheck", 
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildListTitle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, right: 5),
      child: Text("الأموال المعلقة ميدانياً 💸", 
        style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900)
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> user) {
    // 🔥 تنسيق عهدة الموظف في القائمة مقسمة
    final double cash = double.tryParse(user['current_cash_balance']?.toString() ?? '0.0') ?? 0.0;
    final double check = double.tryParse(user['current_check_balance']?.toString() ?? '0.0') ?? 0.0;
    final String formattedCash = NumberFormat('#,##0.00').format(cash);
    final String formattedCheck = NumberFormat('#,##0.00').format(check);
    
    final String name = (user['first_name']?.toString().isNotEmpty == true) ? user['first_name'].toString() : user['username'].toString();
    final bool isDriver = user['role'] == 'driver';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: isDriver ? Colors.orange.shade50 : Colors.teal.shade50,
                  child: Icon(
                    isDriver ? Icons.local_shipping_rounded : Icons.account_balance_wallet_rounded, 
                    color: isDriver ? Colors.orange.shade700 : Colors.teal.shade700, 
                    size: 26
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.blueGrey.shade900)),
                      Text(isDriver ? "سائق ميداني" : "مُحصّل مالي", style: GoogleFonts.cairo(color: Colors.grey.shade500, fontSize: 13, height: 1.2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("كاش 💵", style: GoogleFonts.cairo(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                      Text("$formattedCash دج", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.green.shade700)),
                    ],
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.grey.shade300),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("شيكات 📄", style: GoogleFonts.cairo(fontSize: 12, color: Colors.purple.shade800, fontWeight: FontWeight.bold)),
                      Text("$formattedCheck دج", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.purple.shade700)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkBlue, 
                  foregroundColor: Colors.white,
                  elevation: 0, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showSettlementDetails(user),
                icon: const Icon(Icons.receipt_long_rounded, size: 22),
                label: Text("مراجعة وتصفية العهدة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.task_alt_rounded, size: 80, color: Colors.green.shade200),
            const SizedBox(height: 15),
            Text("الخزينة مصفاة بالكامل", style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: successGreen)),
            Text("لا يوجد عهد معلقة حالياً مع الموظفين", style: GoogleFonts.cairo(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  void _showLoadingOverlay() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
  }

  void _showToast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.all(20),
    ));
  }
}