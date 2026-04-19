import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد مهم لفحص بيئة الويب
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:nfc_manager/nfc_manager.dart'; // 🔥 استيراد مكتبة الـ NFC

import '../../services/api_service.dart';
// 🔥 استيراد نافذة التعديل السحرية
import '../../widgets/admin/edit_user_dialog.dart'; 

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B);
  final Color backgroundGray = const Color(0xFFF8FAFC);
  
  bool _isLoading = true;
  bool _hasError = false;
  List<dynamic> _usersList = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers(); 
  }

  // 📥 جلب المستخدمين
  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; });
    
    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token'));
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/users/'),
        headers: {'Authorization': 'Bearer $token'}
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _usersList = jsonDecode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load');
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  // 🗑️ دالة الحذف الذكية
  Future<void> _deleteUser(int userId, String userName) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.red), const SizedBox(width: 10), Text("تأكيد الحذف", style: GoogleFonts.cairo(fontWeight: FontWeight.bold))]),
        content: Text("هل أنت متأكد أنك تريد حذف ($userName) بشكل نهائي من النظام؟", style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text("نعم، احذف", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token'));
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/users/$userId'), 
        headers: {'Authorization': 'Bearer $token'}
      );

      if ((response.statusCode == 200 || response.statusCode == 204) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم الحذف بنجاح', style: GoogleFonts.cairo()), backgroundColor: Colors.green));
        _fetchUsers(); 
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل الحذف، قد يكون المستخدم مرتبطاً بعمليات مالية.', style: GoogleFonts.cairo()), backgroundColor: Colors.red));
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ في الاتصال بالخادم', style: GoogleFonts.cairo()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // 🪪 برمجة بطاقة الـ NFC للويب (إدخال يدوي/USB)
  // ==========================================
  void _programNfcForUserWeb(int userId, String userName) {
    final TextEditingController nfcManualCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.nfc_rounded, color: Colors.blue),
            const SizedBox(width: 10),
            Text("تحديث بطاقة NFC", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18, color: darkBlue)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("مرر بطاقة الموظف ($userName) على قارئ الـ USB أو أدخل الرقم يدوياً:", style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 15),
            TextField(
              controller: nfcManualCtrl,
              autofocus: true, 
              decoration: InputDecoration(
                labelText: "رقم البطاقة (NFC ID)",
                labelStyle: GoogleFonts.cairo(),
                filled: true,
                fillColor: backgroundGray,
                prefixIcon: const Icon(Icons.contactless_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue)),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  _sendNfcIdToServer(userId, value.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              if (nfcManualCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _sendNfcIdToServer(userId, nfcManualCtrl.text.trim());
              }
            },
            child: Text("حفظ البطاقة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🪪 برمجة بطاقة الـ NFC للهاتف (المسح)
  // ==========================================
  Future<void> _programNfcForUserMobile(int userId, String userName) async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      _showToast("حساس الـ NFC غير متوفر أو معطل في هاتفك!", Colors.red);
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.nfc_rounded, size: 50, color: Colors.blue),
            ),
            const SizedBox(height: 15),
            Text("برمجة بطاقة NFC 🪪", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
            const SizedBox(height: 10),
            Text("يرجى تمرير البطاقة الجديدة خلف هاتفك لربطها بحساب:\n($userName)", style: GoogleFonts.cairo(color: Colors.grey.shade700, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () { NfcManager.instance.stopSession(); Navigator.pop(ctx); },
              child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
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
          // 🔥 الحل السحري لتخطي حماية الدارت الجديدة للـ (tag.data) 
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
        } catch(e) { debugPrint("NFC Read Error: $e"); }

        if (identifier != null && identifier.isNotEmpty) {
          String scannedId = identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
          _sendNfcIdToServer(userId, scannedId);
        } else {
          _showToast("لم نتمكن من قراءة البطاقة، حاول مرة أخرى.", Colors.orange.shade800);
        }
      }
    );
  }

  // 📡 إرسال رقم البطاقة للسيرفر لربطها بالمستخدم
  Future<void> _sendNfcIdToServer(int userId, String nfcId) async {
    _showLoadingOverlay();
    try {
      final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token') ?? '');
      
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/users/$userId/nfc'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({"driver_nfc_id": nfcId}),
      );

      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      if (response.statusCode == 200) {
        _showToast("✅ تم ربط بطاقة الـ NFC بالمستخدم بنجاح!", Colors.green.shade700);
        _fetchUsers(); // تحديث القائمة
      } else {
        _showToast("❌ فشل في ربط البطاقة، قد تكون مستخدمة بالفعل.", Colors.red.shade800);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _showToast("❌ خطأ في الاتصال بالخادم", Colors.red.shade800);
    }
  }

  void _showLoadingOverlay() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
  }

  void _showToast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)), 
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(20),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb; // 🔥 متغير الويب السحري

    return Scaffold(
      backgroundColor: backgroundGray,
      appBar: AppBar(
        title: Text("إدارة الحسابات والصلاحيات", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        // 🔥 إخفاء القائمة العلوية في الكمبيوتر
        leading: isDesktop ? const SizedBox.shrink() : null,
      ),
      body: RefreshIndicator(
        color: primaryRed,
        backgroundColor: Colors.white,
        onRefresh: _fetchUsers,
        child: _buildBodyContent(isDesktop), // تمرير بيئة التشغيل لدالة البناء
      ),
    );
  }

  // 🧩 التحكم في حالة الواجهة وتغيير الشبكة
  Widget _buildBodyContent(bool isDesktop) {
    if (_isLoading) return _buildShimmerLoading(isDesktop);
    if (_hasError) return _buildErrorState();

    if (_usersList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off_rounded, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 15),
            Text("لا يوجد مستخدمين مسجلين حالياً", style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey.shade600))
          ],
        )
      );
    }

    // 🔥 اختيار العرض بناءً على نوع الجهاز (ويب = GridView, هاتف = ListView)
    return isDesktop
        ? GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // عرض مستخدمين اثنين في كل سطر
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 2.2, // نسبة الطول للعرض للبطاقة
            ),
            itemCount: _usersList.length,
            itemBuilder: (context, index) => _buildUserCard(_usersList[index], isDesktop),
          )
        : ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(20),
            itemCount: _usersList.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildUserCard(_usersList[index], isDesktop),
              );
            },
          );
  }

  // 🃏 بطاقة المستخدم الفردية
  Widget _buildUserCard(Map<String, dynamic> user, bool isDesktop) {
    final String role = user['role'] ?? 'مجهول';
    final bool canHaveNfc = role == 'driver' || role == 'collector';
    
    // 🎨 ألوان الرتب
    Color roleColor;
    String roleLabel;
    IconData roleIcon;
    switch(role) {
      case 'admin': roleColor = Colors.purple; roleLabel = 'مدير نظام'; roleIcon = Icons.admin_panel_settings; break;
      case 'driver': roleColor = Colors.orange.shade700; roleLabel = 'سائق ميداني'; roleIcon = Icons.local_shipping; break;
      case 'collector': roleColor = Colors.indigo; roleLabel = 'محصل مالي'; roleIcon = Icons.account_balance_wallet; break;
      case 'customer': roleColor = Colors.blue.shade700; roleLabel = 'زبون / شركة'; roleIcon = Icons.storefront; break;
      default: roleColor = Colors.grey; roleLabel = 'غير محدد'; roleIcon = Icons.person;
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero, // تصفير الهامش لأن الجريد واللست يتكفلان بالمسافات
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // 🔥 تم تغيير withOpacity إلى withValues لإصلاح التنبيهات الزرقاء
                CircleAvatar(backgroundColor: roleColor.withValues(alpha: 0.1), child: Icon(roleIcon, color: roleColor)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['username'] ?? 'بدون اسم', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(user['phone'] ?? 'لا يوجد هاتف', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(roleLabel, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: roleColor)),
                )
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (canHaveNfc)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: darkBlue),
                    // 🔥 توجيه حسب نوع الجهاز للـ NFC
                    onPressed: () {
                      if (isDesktop) {
                        _programNfcForUserWeb(user['id'], user['username']);
                      } else {
                        _programNfcForUserMobile(user['id'], user['username']);
                      }
                    },
                    icon: Icon(isDesktop ? Icons.keyboard_rounded : Icons.nfc_rounded, size: 18, color: user['driver_nfc_id'] != null ? Colors.green : Colors.grey),
                    label: Text(user['driver_nfc_id'] != null ? "تحديث البطاقة" : (isDesktop ? "ربط بطاقة USB" : "برمجة NFC"), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                  )
                else
                  const SizedBox.shrink(),
                  
                // 🔥 إضافة أزرار التحكم (التعديل والحذف) بجوار بعضها
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✏️ زر التعديل الجديد
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                      tooltip: "تعديل الحساب",
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => EditUserDialog(
                            user: user,
                            onSuccess: () {
                              _fetchUsers(); // تحديث القائمة بعد التعديل
                              _showToast("تم تحديث بيانات ${user['username']} بنجاح ✅", Colors.green);
                            },
                          ),
                        );
                      },
                    ),
                    
                    // 🗑️ زر الحذف القديم
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      tooltip: "حذف الحساب",
                      onPressed: () => _deleteUser(user['id'], user['username']),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // 🪄 تأثير التحميل (Shimmer) يتجاوب مع الويب
  Widget _buildShimmerLoading(bool isDesktop) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200, highlightColor: Colors.white,
      child: isDesktop
        ? GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 2.2),
            itemCount: 6,
            itemBuilder: (_, __) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: 6,
            itemBuilder: (_, __) => Container(height: 120, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          ),
    );
  }

  // 🛑 شاشة الخطأ
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text("تعذر جلب البيانات", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: primaryRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _fetchUsers,
            icon: const Icon(Icons.refresh_rounded),
            label: Text("إعادة المحاولة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}