import 'dart:convert';
import 'dart:io' as io; 
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:open_filex/open_filex.dart'; 
import '../../services/api_service.dart';

class CustomerFilesArchiveScreen extends StatefulWidget {
  const CustomerFilesArchiveScreen({super.key});

  @override
  State<CustomerFilesArchiveScreen> createState() => _CustomerFilesArchiveScreenState();
}

class _CustomerFilesArchiveScreenState extends State<CustomerFilesArchiveScreen> {
  List<dynamic> _vaultOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchArchiveOrders();
  }

  Future<void> _fetchArchiveOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/all-orders'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        List<dynamic> allOrders = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _vaultOrders = allOrders.where((o) => 
              (o['customer_check_file'] != null && o['customer_check_file'].toString().isNotEmpty) || 
              (o['customer_company_file'] != null && o['customer_company_file'].toString().isNotEmpty)
            ).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openPdfFile(String base64String, String fileName) async {
    try {
      if (kIsWeb) {
        final uri = Uri.parse('data:application/pdf;base64,$base64String');
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      } else {
        Uint8List bytes = base64Decode(base64String);
        final dir = await getApplicationDocumentsDirectory();
        final file = io.File('${dir.path}/$fileName.pdf');
        await file.writeAsBytes(bytes, flush: true);
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      debugPrint("Error handling PDF: $e");
    }
  }

  void _showFilePreview(String base64String, String titleText, Color themeColor) {
    try {
      bool isPdf = base64String.startsWith('JVBER') || base64String.startsWith('JVBE');
      Uint8List bytes = base64Decode(base64String);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          contentPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Icon(Icons.attachment_rounded, color: themeColor),
              const SizedBox(width: 8),
              Expanded(child: Text(titleText, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.5,
            child: isPdf 
              ? Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.red.shade50,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 70),
                      const SizedBox(height: 15),
                      Text("هذا المرفق بصيغة PDF", style: GoogleFonts.cairo(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 25),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx); 
                          _openPdfFile(base64String, "Dante_Attachment_${DateTime.now().millisecondsSinceEpoch}"); 
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.download_rounded),
                        label: Text("فتح الملف", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                )
              : InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إغلاق", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.grey.shade700)))
          ],
        )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تعذر فتح الملف")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        title: Text("أرشيف ملفات الزبائن والشيكات", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _vaultOrders.isEmpty 
          ? Center(child: Text("لا توجد ملفات أو شيكات مرفوعة بعد", style: GoogleFonts.cairo(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _vaultOrders.length,
              itemBuilder: (context, index) {
                final order = _vaultOrders[index];
                final bool hasCheck = order['customer_check_file'] != null && order['customer_check_file'].toString().isNotEmpty;
                final bool hasPdf = order['customer_company_file'] != null && order['customer_company_file'].toString().isNotEmpty;

                return Card(
                  elevation: 0, margin: const EdgeInsets.only(bottom: 10), color: Colors.purple.shade50.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.purple.shade100)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(order['customer_name'] ?? 'مجهول', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16))),
                            Text(order['tracking_number'] ?? '-', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            if (hasCheck) 
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showFilePreview(order['customer_check_file'], "شيك الزبون", Colors.purple),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade50, foregroundColor: Colors.purple.shade800, elevation: 0),
                                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                                  label: Text("صورة الشيك", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                                )
                              ),
                            if (hasCheck && hasPdf) const SizedBox(width: 8),
                            if (hasPdf) 
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showFilePreview(order['customer_company_file'], "ملف / فاتورة الشركة", Colors.red),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade800, elevation: 0),
                                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                  label: Text("ملف الشركة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                                )
                              ),
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