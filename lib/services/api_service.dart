import 'dart:async'; 
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart'; 
import 'sync_service.dart'; 

class ApiService {
  // 🔥 الرابط السحابي الحي (Render) - النسخة المعتمدة للإصدار النهائي
  static String get baseUrl {
    return 'https://dante-trace-api.onrender.com'; 
  }

  // ==========================================================
  // 🔑 مساعدات عامة (Helpers)
  // ==========================================================
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<int?> getUserId() async {
    final token = await _getToken();
    if (token != null && !JwtDecoder.isExpired(token)) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      return decodedToken['user_id']; 
    }
    return null;
  }

  static Future<String?> getUserRole() async {
    final token = await _getToken();
    if (token != null && !JwtDecoder.isExpired(token)) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      return decodedToken['role']; 
    }
    return null;
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ==========================================================
  // 1. نظام المصادقة (Auth)
  // ==========================================================
  static Future<bool> login(String username, String password) async {
    try {
      debugPrint("⏳ جاري الاتصال بالسيرفر...");
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': username.trim(), 'password': password.trim()}, 
      ).timeout(const Duration(seconds: 60)); 

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String token = data['access_token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('username', username.trim()); 
        
        debugPrint("✅ تم تسجيل الدخول بنجاح");
        return true;
      } else {
        debugPrint("❌ فشل الدخول: ${response.body}");
      }
      return false;
    } catch (e) {
      debugPrint("🚨 خطأ في الاتصال: $e");
      return false;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('username');
  }

  // ==========================================================
  // 🏢 2. إدارة المستخدمين (HR & Users)
  // ==========================================================
  static Future<List<dynamic>> getAllUsers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/users/'), headers: headers)
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 200 ? jsonDecode(utf8.decode(response.bodyBytes)) : [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getMyProfile() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'), 
        headers: headers
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      return null;
    }
  }

  static Future<bool> registerUser({
    required String username, required String password, required String firstName, 
    required String lastName, required String email, required String phone, 
    String? phone2, String? phone3, String? businessName, 
    required String role, String? nfcId,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/users/'),
        headers: headers,
        body: jsonEncode({
          "username": username.trim(), "email": email.trim(), "password": password.trim(),
          "first_name": firstName.trim(), "last_name": lastName.trim(), "phone": phone.trim(),
          if (businessName != null && businessName.trim().isNotEmpty) "business_name": businessName.trim(),
          "role": role, "company_id": 1, 
          if (nfcId != null && nfcId.trim().isNotEmpty) "driver_nfc_id": nfcId.trim(),
        }),
      ).timeout(const Duration(seconds: 60));
      
      if(response.statusCode != 200 && response.statusCode != 201){
        debugPrint("🚨 Error Registering User: ${response.body}");
      }
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("🚨 Exception Registering User: $e");
      return false;
    }
  }

  static Future<bool> updateUser(int userId, Map<String, dynamic> updateData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId'),
        headers: headers,
        body: jsonEncode(updateData),
      ).timeout(const Duration(seconds: 30));

      if(response.statusCode != 200) {
        debugPrint("🚨 Error Updating User: ${response.body}");
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("🚨 Update User Exception: $e");
      return false;
    }
  }

  // 🔥 دالة حذف مستخدم (محمية برمز المدير)
  static Future<Map<String, dynamic>> deleteUser(int userId, String masterPin) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId?master_pin=$masterPin'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        return {"success": true, "message": "تم حذف المستخدم بنجاح"};
      } else {
        return {"success": false, "message": responseData["detail"] ?? "الرمز السري خاطئ أو المستخدم مرتبط ببيانات"};
      }
    } catch (e) {
      return {"success": false, "message": "انقطع الاتصال بالسيرفر."};
    }
  }

  // ==========================================================
  // 💰 3. المحرك المالي والمصاريف (Financial & Expenses Engine)
  // ==========================================================
  
  // 🔥 تم التحديث: إضافة `receiptImage` كمعامل اختياري للصرف المباشر
  static Future<bool> submitDriverExpense(double amount, String description, {String? receiptImage}) async {
    try {
      final headers = await _getHeaders();
      
      // تجهيز البيانات
      final Map<String, dynamic> bodyData = {
        "amount": amount, 
        "description": description
      };
      
      // تضمين صورة البون (Base64) إن وُجدت
      if (receiptImage != null && receiptImage.isNotEmpty) {
        bodyData["receipt_image"] = receiptImage;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/driver/expenses'),
        headers: headers,
        body: jsonEncode(bodyData),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        debugPrint("🚨 Error Submitting Expense: ${response.body}");
      }
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("🚨 Exception Submitting Expense: $e");
      return false;
    }
  }

  static Future<List<dynamic>> getPendingExpenses() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/admin/expenses/pending'), headers: headers)
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 200 ? jsonDecode(utf8.decode(response.bodyBytes)) : [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> reviewExpense(int expenseId, String action, String adminNote) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/admin/expenses/$expenseId/review'),
        headers: headers,
        body: jsonEncode({"action": action, "admin_note": adminNote}),
      ).timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> registerPayment(Map<String, dynamic> paymentData) async {
    try {
      final headers = await _getHeaders();
      final currentUserId = await getUserId();
      final response = await http.post(
        Uri.parse('$baseUrl/finance/payments/?current_user_id=$currentUserId'),
        headers: headers,
        body: jsonEncode(paymentData),
      ).timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> initiateTransfer(int toUserId, double cash, List<int> chequeIds) async {
    try {
      final headers = await _getHeaders();
      final fromUserId = await getUserId();
      final response = await http.post(
        Uri.parse('$baseUrl/finance/transfers/initiate/?from_user_id=$fromUserId'),
        headers: headers,
        body: jsonEncode({"to_user_id": toUserId, "amount_cash": cash, "cheque_payment_ids": chequeIds}),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) return jsonDecode(utf8.decode(response.bodyBytes));
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> completeTransferNFC(int transferId, String receiverNfcId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/finance/transfers/complete/$transferId?receiver_nfc_id=$receiverNfcId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==========================================================
  // 🛒 4. المنتجات وأسعار B2B (Products & Custom Pricing)
  // ==========================================================
  static Future<bool> createProduct(String name, double price, String iconName) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/admin/products'),
        headers: headers,
        body: jsonEncode({"name": name, "base_price": price, "icon_name": iconName}),
      ).timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<dynamic>> getDynamicProducts() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/customer/products'), headers: headers)
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 200 ? jsonDecode(utf8.decode(response.bodyBytes)) : [];
    } catch (e) {
      return [];
    }
  }

  // 🔥 دالة حذف منتج (محمية برمز المدير)
  static Future<Map<String, dynamic>> deleteProduct(int productId, String masterPin) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/products/$productId?master_pin=$masterPin'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        return {"success": true, "message": responseData["message"] ?? "تم الحذف بنجاح"};
      } else {
        return {"success": false, "message": responseData["detail"] ?? "حدث خطأ أو الرمز السري خاطئ"};
      }
    } catch (e) {
      return {"success": false, "message": "انقطع الاتصال بالسيرفر. يرجى المحاولة لاحقاً."};
    }
  }

  static Future<bool> setCustomPrice(int customerId, int productId, double customPrice) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/admin/customer-price'),
        headers: headers,
        body: jsonEncode({"customer_id": customerId, "product_id": productId, "custom_price": customPrice}),
      ).timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<dynamic>> getCustomPrices() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/admin/customer-prices'), headers: headers)
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 200 ? jsonDecode(utf8.decode(response.bodyBytes)) : [];
    } catch (e) {
      return [];
    }
  }

  // ==========================================================
  // 📦 5. إدارة الطلبيات والسائقين (Logistics, Split & Schedule)
  // ==========================================================
  
  // 🔥 دالة حذف طلبية (محمية برمز المدير)
  static Future<Map<String, dynamic>> deleteShipment(int shipmentId, String masterPin) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/shipments/$shipmentId?master_pin=$masterPin'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        return {"success": true, "message": "تم حذف الطلبية بنجاح"};
      } else {
        return {"success": false, "message": responseData["detail"] ?? "الرمز السري خاطئ أو غير مصرح لك"};
      }
    } catch (e) {
      return {"success": false, "message": "انقطع الاتصال بالسيرفر."};
    }
  }

  static Future<bool> createCustomerOrder(Map<String, dynamic> orderData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/customer/order'),
        headers: headers,
        body: jsonEncode(orderData),
      ).timeout(const Duration(seconds: 60));
      if(response.statusCode != 200 && response.statusCode != 201) {
        debugPrint("🚨 Create Order Error: ${response.body}");
      }
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<List<dynamic>> getCustomerHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/customer/my-orders'), headers: headers)
          .timeout(const Duration(seconds: 30));
          
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data;
      } else {
        debugPrint("🚨 Fetch History Error: ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint("🚨 Fetch History Exception: $e");
      return [];
    }
  }
  
  static Future<bool> customerApproveSchedule(int shipmentId, String status, {String? rejectionReason}) async {
    try {
      final headers = await _getHeaders();
      final bodyData = {
        "status": status,
      };
      
      if (status == "rejected" && rejectionReason != null && rejectionReason.isNotEmpty) {
        bodyData["rejection_reason"] = rejectionReason;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/customer/shipments/$shipmentId/approve'),
        headers: headers,
        body: jsonEncode(bodyData),
      ).timeout(const Duration(seconds: 30));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error on customer approval: $e");
      return false;
    }
  }

  static Future<bool> assignOrderToDriver(int shipmentId, int driverId, {bool skipNfc = true}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/admin/shipments/$shipmentId/assign'),
        headers: headers,
        body: jsonEncode({
          "driver_id": driverId,
          "skip_nfc": skipNfc 
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error assigning order: $e");
      return false;
    }
  }

  static Future<List<dynamic>> getDriverAssignedTasks() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/driver/my-assigned-tasks'), headers: headers)
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 200 ? jsonDecode(utf8.decode(response.bodyBytes)) : [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> updateOrderStatus(int shipmentId, String status) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/driver/update-status/$shipmentId?status=$status'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error updating order status: $e");
      return false;
    }
  }

  static Future<bool> splitShipment(Map<String, dynamic> advancedSplitData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/admin/split-shipment'), 
        headers: headers,
        body: jsonEncode(advancedSplitData),
      ).timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> rescheduleOrder(int shipmentId, DateTime newDate, bool requireApproval) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/admin/shipments/$shipmentId/reschedule'),
        headers: headers,
        body: jsonEncode({
          "new_date": newDate.toIso8601String(),
          "require_approval": requireApproval
        }),
      ).timeout(const Duration(seconds: 30));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error Rescheduling: $e");
      return false;
    }
  }

  // ==========================================================
  // 💻 6. لوحة التحكم وتقارير الإدارة (Admin Dashboard & Invoicing)
  // ==========================================================
  static Future<Map<String, dynamic>?> getDashboardStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/dashboard/'), headers: headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) return jsonDecode(utf8.decode(response.bodyBytes)); 
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<dynamic>> getPendingOrders() async => _fetchOrderList('pending-orders');
  static Future<List<dynamic>> getApprovedOrders() async => _fetchOrderList('approved-orders'); 
  static Future<List<dynamic>> getSettledOrders() async => _fetchOrderList('settled-orders');

  static Future<List<dynamic>> _fetchOrderList(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/admin/$endpoint'), headers: headers)
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 200 ? jsonDecode(utf8.decode(response.bodyBytes)) : [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getInvoiceData(int shipmentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/invoice-data/$shipmentId'),
        headers: headers,
      ).timeout(const Duration(seconds: 60)); 
      return response.statusCode == 200 ? jsonDecode(utf8.decode(response.bodyBytes)) : null;
    } catch (e) {
      return null;
    }
  }

  // ==========================================================
  // 🤝 7. المصافحة الثلاثية (Handshake & Settlement)
  // ==========================================================
  static Future<bool> performHandshake(String driverNfc, String trackingNumber) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/shipments/nfc-handshake/'), 
        headers: headers,
        body: jsonEncode({"driver_nfc_id": driverNfc, "tracking_number": trackingNumber}),
      ).timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (e) {
      await SyncService.saveOfflineHandshake(driverNfc, trackingNumber);
      return true; 
    }
  }

  static Future<Map<String, dynamic>> settleDriverAccount(String driverNfcId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/admin/settle-driver/'),
        headers: headers,
        body: jsonEncode({"driver_nfc_id": driverNfcId}),
      ).timeout(const Duration(seconds: 30));
      
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        return {"success": true, "message": data['message'] ?? "تمت التصفية بنجاح", "data": data};
      } else {
        return {"success": false, "message": data['detail'] ?? "فشل الاتصال"};
      }
    } catch (e) {
      return {"success": false, "message": "خطأ في الشبكة: $e"};
    }
  }

  // ==========================================================
  // 💸 8. النظام المالي الجديد (تصريح الزبون وتأكيد الإدارة) 🔥
  // ==========================================================
  static Future<bool> customerDeclarePayment(int shipmentId, List<Map<String, dynamic>> payments) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/customer/shipments/$shipmentId/declare-payment'),
        headers: headers,
        body: jsonEncode({"payments": payments}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint("🚨 Error Declaring Payment: ${response.body}");
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("🚨 Exception Declaring Payment: $e");
      return false;
    }
  }

  static Future<bool> adminVerifyPayment(int shipmentId, double cash, double check) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/admin/shipments/$shipmentId/verify-payment'),
        headers: headers,
        body: jsonEncode({
          "cash_received": cash,
          "check_received": check
        })
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint("🚨 Error Verifying Payment: ${response.body}");
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("🚨 Exception Verifying Payment: $e");
      return false;
    }
  }

  static Future<bool> adminRejectPayment(int shipmentId, String reason) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/admin/shipments/$shipmentId/reject-payment'),
        headers: headers,
        body: jsonEncode({
          "reason": reason.isEmpty ? "خطأ في التصريح، يرجى المراجعة والمحاولة مجدداً." : reason
        })
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint("🚨 Error Rejecting Payment: ${response.body}");
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("🚨 Exception Rejecting Payment: $e");
      return false;
    }
  }

  // ==========================================================
  // 💼 9. عمليات المحصل الميداني (Collector Operations)
  // ==========================================================
  static Future<Map<String, dynamic>?> getCollectorDebtors() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/collector/debtors'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching debtors: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>> collectMoneyFromDriver(String driverNfcId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/collector/collect-from-driver'),
        headers: headers,
        body: jsonEncode({
          "driver_nfc_id": driverNfcId,
          "tracking_number": "N/A" 
        }),
      ).timeout(const Duration(seconds: 30));
      
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        return {"success": true, "message": data['message'] ?? "تم التحصيل بنجاح", "new_balance": data['collector_new_balance']};
      }
      return {"success": false, "message": data['detail'] ?? "حدث خطأ"};
    } catch (e) {
      return {"success": false, "message": "انقطع الاتصال بالسيرفر"};
    }
  }

  static Future<Map<String, dynamic>> collectMoneyFromCustomer(int shipmentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/collector/collect-from-customer/$shipmentId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        return {"success": true, "message": data['message'] ?? "تم التحصيل بنجاح", "new_balance": data['collector_new_balance']};
      }
      return {"success": false, "message": data['detail'] ?? "حدث خطأ"};
    } catch (e) {
      return {"success": false, "message": "انقطع الاتصال بالسيرفر"};
    }
  }

  // ==========================================================
  // 🛡️ 10. نظام الحارس (Version Checker)
  // ==========================================================
  static Future<String> getRequiredAppVersion() async {
    try {
      // 💡 مستقبلاً يمكنك جلب هذا الرقم عبر API من قاعدة البيانات
      // final response = await http.get(Uri.parse('$baseUrl/config/version'));
      // return jsonDecode(response.body)['required_version'];
      
      // حالياً، قم بتغيير هذا الرقم يدوياً عندما ترفع APK جديد في الواتساب
      return "1.0.0"; 
    } catch (e) {
      return "1.0.0"; // افتراضي في حالة تعذر الاتصال لتجنب إغلاق التطبيق بالخطأ
    }
  }
}