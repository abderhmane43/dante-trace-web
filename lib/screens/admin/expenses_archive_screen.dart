import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class ExpensesArchiveScreen extends StatefulWidget {
  const ExpensesArchiveScreen({super.key});

  @override
  State<ExpensesArchiveScreen> createState() => _ExpensesArchiveScreenState();
}

class _ExpensesArchiveScreenState extends State<ExpensesArchiveScreen> {
  List<dynamic> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/expenses/all'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _expenses = jsonDecode(utf8.decode(response.bodyBytes));
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImagePreview(String base64String) {
    try {
      Uint8List bytes = base64Decode(base64String);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          contentPadding: EdgeInsets.zero,
          content: InteractiveViewer(
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("إغلاق", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.grey.shade700))
            )
          ],
        )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تعذر عرض الصورة")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        title: Text("أرشيف بونات الصرف", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _expenses.isEmpty 
          ? Center(child: Text("لا توجد مصروفات مسجلة", style: GoogleFonts.cairo(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _expenses.length,
              itemBuilder: (context, index) {
                final exp = _expenses[index];
                final double amount = double.tryParse(exp['amount']?.toString() ?? '0') ?? 0.0;
                final bool hasReceipt = exp['receipt_image'] != null && exp['receipt_image'].toString().isNotEmpty;

                return Card(
                  elevation: 0, margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(exp['driver_name'] ?? 'مجهول', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("${NumberFormat('#,##0.00').format(amount)} دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(exp['description'] ?? '', style: GoogleFonts.cairo(color: Colors.grey.shade700)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(exp['date'] ?? '', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                            const Spacer(),
                            if (hasReceipt)
                              ElevatedButton.icon(
                                onPressed: () => _showImagePreview(exp['receipt_image']),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade50, foregroundColor: Colors.orange.shade800, elevation: 0),
                                icon: const Icon(Icons.receipt, size: 16),
                                label: Text("عرض البون", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                              )
                          ],
                        )
                      ],
                    ),
                  )
                );
              },
            ),
    );
  }
}