import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد فحص الويب
import 'package:google_fonts/google_fonts.dart';
import 'package:nfc_manager/nfc_manager.dart';

// 🔥 تم استخدام المسار المطلق لضمان عدم حدوث أي أخطاء في الروابط
import 'package:dante_trace_mobile/services/api_service.dart';

class NfcHandshakeScreen extends StatefulWidget {
  final String operationTitle;
  final Color themeColor;

  const NfcHandshakeScreen({super.key, required this.operationTitle, required this.themeColor});

  @override
  State<NfcHandshakeScreen> createState() => _NfcHandshakeScreenState();
}

class _NfcHandshakeScreenState extends State<NfcHandshakeScreen> {
  final TextEditingController _packageTrackingController = TextEditingController();
  String? _driverNfcId;
  bool _isProcessing = false;
  bool _isScanning = false;
  String _scanMessage = "اضغط على الزر لمسح بطاقة السائق";

  @override
  void dispose() {
    NfcManager.instance.stopSession(); 
    _packageTrackingController.dispose(); 
    super.dispose();
  }

  // =========================================================================
  // 📡 محرك قراءة الـ NFC (المحرك الآمن والموحد)
  // =========================================================================
  void _startDriverNfcScan() async {
    // 🔥 الحماية من الويب
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ خاصية NFC غير مدعومة في متصفح الويب!', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ حساس الـ NFC غير مفعل في هاتفك!', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isScanning = true;
      _driverNfcId = null;
      _scanMessage = "📱 قرب بطاقة السائق من ظهر الهاتف...";
    });

    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
      onDiscovered: (NfcTag tag) async {
        // إيقاف الجلسة فوراً بمجرد التقاط البطاقة لمنع التكرار
        NfcManager.instance.stopSession();
        
        List<int>? identifier;

        try {
          // 🛡️ التفكيك الآمن للبيانات (The Ultimate Safe Parser)
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
          debugPrint("🚨 خطأ أثناء تحليل NFC: $e");
        }

        if (mounted) {
          setState(() {
            _isScanning = false;
            if (identifier != null && identifier.isNotEmpty) {
              // تحويل المعرف إلى Hex String بشكل نظيف
              _driverNfcId = identifier.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
              _scanMessage = "✅ تم التقاط بطاقة السائق بنجاح";
            } else {
              _driverNfcId = null;
              _scanMessage = "⚠️ فشل القراءة. يرجى المحاولة مجدداً.";
            }
          });
        }
      },
    );
  }

  // 🧠 تحديد نصوص وواجهة المصافحة ديناميكياً
  Map<String, dynamic> _getHandshakeContext() {
    if (widget.operationTitle.contains("تصفية")) {
      return {
        "step": "المصافحة 3 (النهائية)",
        "instruction": "أدخل رقم الطرد ثم امسح بطاقة السائق لتأكيد تصفية العهدة.",
        "success_msg": "تم توريد المبلغ للخزينة وتصفية عهدة السائق بنجاح 💰",
        "icon": Icons.account_balance_wallet_rounded
      };
    } else if (widget.operationTitle.contains("تأكيد الاستلام") || widget.operationTitle.contains("الزبون")) {
      return {
        "step": "المصافحة 2 (الميدانية)",
        "instruction": "أدخل رقم الطرد وامسح بطاقة السائق لتأكيد التسليم للزبون.",
        "success_msg": "تم تسليم الطرد للزبون وانتقال الكاش لعهدة السائق 🤝",
        "icon": Icons.verified_user_rounded
      };
    } else {
      return {
        "step": "المصافحة 1 (بوابة المستودع)",
        "instruction": "أدخل رقم الطرد ثم امسح بطاقة السائق لتسليمه العهدة.",
        "success_msg": "تم نقل عهدة الطرد إلى السائق وهو في الطريق الآن 🚚",
        "icon": Icons.outbound_rounded
      };
    }
  }

  void _handleHandshake() async {
    if (_packageTrackingController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ يرجى إدخال رقم تتبع الطرد أولاً', style: GoogleFonts.cairo()), backgroundColor: Colors.orange.shade800));
      return;
    }

    if (_driverNfcId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ يرجى مسح بطاقة السائق بنجاح أولاً', style: GoogleFonts.cairo()), backgroundColor: Colors.red.shade800));
      return;
    }

    setState(() => _isProcessing = true);

    bool success = await ApiService.performHandshake(
      _driverNfcId!,
      _packageTrackingController.text.trim(),
    );

    if (mounted) {
      setState(() => _isProcessing = false);

      if (success) {
        _showSuccessDialog();
        setState(() {
          _driverNfcId = null;
          _packageTrackingController.clear();
          _scanMessage = "اضغط على الزر لمسح بطاقة السائق";
        });
      } else {
        _showErrorDialog();
      }
    }
  }

  void _showSuccessDialog() {
    final contextData = _getHandshakeContext();
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 70),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("العملية تمت بنجاح!", style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(contextData['success_msg'], textAlign: TextAlign.center, style: GoogleFonts.cairo(color: Colors.grey.shade700, fontSize: 15)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.themeColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)
            ),
            onPressed: () { 
              Navigator.pop(context); 
              Navigator.pop(context); 
            }, 
            child: Text("تم وإغلاق", style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 70),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("توقف أمني!", style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 10),
            Text("العملية مرفوضة. يرجى التأكد من مطابقة بطاقة السائق لرقم الطرد المدخل.", textAlign: TextAlign.center, style: GoogleFonts.cairo(color: Colors.grey.shade700, fontSize: 14)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text("إغلاق والمحاولة مجدداً", style: GoogleFonts.cairo(color: Colors.grey.shade800, fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contextData = _getHandshakeContext();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.operationTitle, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.all(24.0),
            padding: const EdgeInsets.all(30.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 25, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: widget.themeColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(contextData['icon'], size: 50, color: widget.themeColor),
                ),
                const SizedBox(height: 20),
                Text(contextData['step'], style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: widget.themeColor)),
                const SizedBox(height: 8),
                Text(contextData['instruction'], textAlign: TextAlign.center, style: GoogleFonts.cairo(color: Colors.grey.shade600, fontSize: 14, height: 1.4)),
                
                const Padding(padding: EdgeInsets.symmetric(vertical: 25), child: Divider()),
                
                // 📦 حقل إدخال رقم الطرد يدوياً 
                TextField(
                  controller: _packageTrackingController,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: "رقم تتبع الطرد",
                    labelStyle: GoogleFonts.cairo(),
                    hintText: "DANTE-PKG-...",
                    hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.qr_code_scanner_rounded, color: widget.themeColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: widget.themeColor, width: 2)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 20),

                // 📡 منطقة إشعارات الـ NFC للسائق
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                  decoration: BoxDecoration(
                    color: _isScanning ? Colors.blue.shade50 : (_driverNfcId != null ? Colors.green.shade50 : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isScanning ? Colors.blue.shade200 : (_driverNfcId != null ? Colors.green.shade200 : Colors.grey.shade300))
                  ),
                  child: Row(
                    children: [
                      Icon(_isScanning ? Icons.nfc : (_driverNfcId != null ? Icons.check_circle : Icons.contactless_outlined), 
                           color: _isScanning ? Colors.blue : (_driverNfcId != null ? Colors.green : Colors.grey), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _scanMessage,
                          style: GoogleFonts.cairo(
                            color: _isScanning ? Colors.blue.shade800 : (_driverNfcId != null ? Colors.green.shade800 : Colors.black87),
                            fontWeight: _isScanning || _driverNfcId != null ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // 💳 زر مسح بطاقة السائق
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _startDriverNfcScan,
                    icon: Icon(_driverNfcId == null ? Icons.contactless_outlined : Icons.refresh_rounded, color: Colors.white),
                    label: Text(
                      _driverNfcId == null ? "بدء مسح البطاقة (NFC)" : "إعادة مسح البطاقة", 
                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _driverNfcId == null ? Colors.orange.shade700 : Colors.blueGrey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                
                const SizedBox(height: 35),
                
                // 🚀 الزر النهائي للمصافحة
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: (_isProcessing || _driverNfcId == null || _packageTrackingController.text.isEmpty) ? null : _handleHandshake,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.themeColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: (_driverNfcId != null && _packageTrackingController.text.isNotEmpty) ? 5 : 0,
                    ),
                    icon: _isProcessing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.verified_user_rounded, color: Colors.white),
                    label: Text(
                      _isProcessing ? "جاري التشفير والمطابقة..." : "اعتماد العملية وربط العهدة", 
                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}