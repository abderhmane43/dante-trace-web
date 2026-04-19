import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class SyncService {
  // الاتصال بالصندوق الأسود 
  static final _box = Hive.box('offline_sync_box');
  
  // 🛡️ قفل الأمان لمنع تداخل عمليات المزامنة إذا تذبذبت الشبكة
  static bool _isSyncing = false; 

  // 1. 🌐 رادار مراقبة الشبكة (يعمل في الخلفية)
  static void initializeNetworkListener() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        debugPrint("🌐 عاد الإنترنت! جاري فحص الصندوق الأسود...");
        syncPendingHandshakes();
      }
    });
  }

  // 2. 📦 تخزين المصافحة في الصندوق الأسود (عند غياب الإنترنت)
  static Future<void> saveOfflineHandshake(String driverNfcId, String trackingNumber) async {
    final data = {
      "driver_nfc_id": driverNfcId,
      "tracking_number": trackingNumber, // 🔥 تم التصحيح لتطابق الباك إند
      "timestamp": DateTime.now().toIso8601String(),
    };
    
    await _box.add(data);
    debugPrint("🔒 تم حفظ المصافحة محلياً بنجاح. سيتم إرسالها عند عودة الإنترنت.");
  }

  // 3. 🚀 إرسال البيانات المتراكمة للسيرفر (عند عودة الإنترنت)
  static Future<void> syncPendingHandshakes() async {
    // التحقق من أن الصندوق ليس فارغاً وأننا لسنا في حالة مزامنة حالية
    if (_box.isEmpty || _isSyncing) {
      return; 
    }

    _isSyncing = true; // إغلاق القفل
    debugPrint("⚠️ يوجد ${_box.length} عملية مصافحة معلقة. جاري الإرسال...");

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) {
      _isSyncing = false;
      return;
    }

    // نأخذ نسخة من مفاتيح البيانات لتجنب مشاكل الحذف أثناء الدوران
    final keys = _box.keys.toList();

    for (var key in keys) {
      final scanData = _box.get(key);
      
      try {
        final response = await http.put(
          Uri.parse('${ApiService.baseUrl}/shipments/nfc-handshake/'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            "driver_nfc_id": scanData['driver_nfc_id'],
            "tracking_number": scanData['tracking_number'] // 🔥 تم التصحيح هنا
          }),
        ).timeout(const Duration(seconds: 15)); // ⏱️ وضع حد أقصى للانتظار

        // معالجة الردود بذكاء
        if (response.statusCode == 200) {
          debugPrint("✅ تمت مزامنة الطرد للسيرفر بنجاح!");
          await _box.delete(key); 
        } 
        // 🗑️ التخلص من الطلبات السامة (إذا رفضها السيرفر نهائياً لعدم صحتها أو تكرارها)
        else if (response.statusCode == 400 || response.statusCode == 404 || response.statusCode == 422) {
          debugPrint("🗑️ السيرفر رفض العملية بشكل قاطع. تم حذفها من الطابور لمنع الانسداد.");
          await _box.delete(key);
        } 
        else {
          debugPrint("❌ فشلت المزامنة (مشكلة في السيرفر)، الكود: ${response.statusCode}");
        }
      } catch (e) {
        debugPrint("⏳ الإنترنت لا يزال ضعيفاً جداً، سيتم تأجيل المزامنة.");
        break; // نوقف المحاولة وننتظر إشارة أفضل للحفاظ على البطارية
      }
    }
    
    _isSyncing = false; // فتح القفل بعد الانتهاء
  }
}