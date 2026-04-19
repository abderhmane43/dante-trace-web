import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

class CheckoutDialog extends StatefulWidget {
  final double totalAmount;
  final bool isProcessing;
  final Function(String phone, String wilaya, String address, String time, double lat, double lng) onSubmit;

  const CheckoutDialog({
    super.key,
    required this.totalAmount,
    required this.isProcessing,
    required this.onSubmit,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _wilayaController = TextEditingController();
  final _addressController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _isLoadingData = true;
  String _currentUser = ""; // 🔥 متغير لحفظ اسم المستخدم الحالي

  @override
  void initState() {
    super.initState();
    _loadSavedCustomerData(); 
  }

  // 📥 دالة جلب بيانات الزبون (المخصصة له فقط)
  Future<void> _loadSavedCustomerData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. جلب اسم المستخدم الحالي
    _currentUser = prefs.getString('username') ?? 'unknown_user';
    
    if (mounted) {
      setState(() {
        // 2. قراءة البيانات باستخدام المفتاح المخصص (اسم المستخدم + اسم الحقل)
        _phoneController.text = prefs.getString('${_currentUser}_cust_phone') ?? '';
        _wilayaController.text = prefs.getString('${_currentUser}_cust_wilaya') ?? '';
        _addressController.text = prefs.getString('${_currentUser}_cust_address') ?? '';
        _isLoadingData = false;
      });
    }
  }

  // 💾 دالة حفظ بيانات الزبون (بشكل معزول وآمن)
  Future<void> _saveCustomerDataLocally() async {
    final prefs = await SharedPreferences.getInstance();
    // استخدام المفتاح المخصص للحفظ
    await prefs.setString('${_currentUser}_cust_phone', _phoneController.text.trim());
    await prefs.setString('${_currentUser}_cust_wilaya', _wilayaController.text.trim());
    await prefs.setString('${_currentUser}_cust_address', _addressController.text.trim());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _wilayaController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)), 
      firstDate: DateTime.now(), 
      lastDate: DateTime.now().add(const Duration(days: 30)), 
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1976D2)),
          datePickerTheme: DatePickerThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        ),
        child: child!,
      ),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 9, minute: 0),
        builder: (context, child) => Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF1976D2)),
            timePickerTheme: TimePickerThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          ),
          child: child!,
        ),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDate = pickedDate;
          _selectedTime = pickedTime;
        });
      }
    }
  }

  String _getFormattedDateTime() {
    if (_selectedDate == null || _selectedTime == null) return "اضغط لتحديد اليوم والساعة";
    
    final DateTime fullDateTime = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute
    );
    
    return DateFormat('yyyy-MM-dd HH:mm').format(fullDateTime);
  }

  @override
  Widget build(BuildContext context) {
    final String formattedTotal = NumberFormat('#,##0.00').format(widget.totalAmount);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1976D2),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("إتمام الطلبية 🚀", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
            Text("$formattedTotal دج", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 18)),
          ],
        ),
      ),
      content: _isLoadingData 
        ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
        : SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("بيانات التوصيل (محفوظة تلقائياً):", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700, fontSize: 13)),
                const SizedBox(height: 15),
                
                // رقم الهاتف
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  validator: (v) => v!.isEmpty ? "مطلوب" : null,
                  decoration: InputDecoration(
                    labelText: "رقم الهاتف",
                    labelStyle: GoogleFonts.cairo(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.phone_android_rounded, color: Colors.blue.shade700),
                    filled: true, fillColor: Colors.blue.shade50.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),

                // الولاية
                TextFormField(
                  controller: _wilayaController,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                  validator: (v) => v!.isEmpty ? "مطلوب" : null,
                  decoration: InputDecoration(
                    labelText: "الولاية (مثال: بسكرة)",
                    labelStyle: GoogleFonts.cairo(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.map_rounded, color: Colors.blue.shade700),
                    filled: true, fillColor: Colors.blue.shade50.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),

                // العنوان التفصيلي
                TextFormField(
                  controller: _addressController,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                  validator: (v) => v!.isEmpty ? "مطلوب" : null,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: "العنوان بالتفصيل",
                    labelStyle: GoogleFonts.cairo(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.location_on_rounded, color: Colors.blue.shade700),
                    filled: true, fillColor: Colors.blue.shade50.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                // اختيار التاريخ والوقت
                Text("تحديد موعد الاستلام المفضل:", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700, fontSize: 13)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDateTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedDate == null ? Colors.grey.shade100 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _selectedDate == null ? Colors.grey.shade300 : Colors.green.shade400),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, color: _selectedDate == null ? Colors.grey.shade600 : Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getFormattedDateTime(),
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold, 
                              color: _selectedDate == null ? Colors.grey.shade700 : Colors.green.shade800,
                              fontSize: 14
                            )
                          ),
                        ),
                        Icon(Icons.edit_calendar_rounded, size: 18, color: Colors.blue.shade700),
                      ],
                    ),
                  ),
                ),
                if (_selectedDate == null)
                   Padding(
                     padding: const EdgeInsets.only(top: 6, right: 4),
                     child: Text("* يرجى تحديد الموعد ليتمكن السائق من برمجته", style: GoogleFonts.cairo(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                   )
              ],
            ),
          ),
        ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      actions: [
        TextButton(
          onPressed: widget.isProcessing ? null : () => Navigator.pop(context),
          child: Text("تراجع", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
          ),
          onPressed: widget.isProcessing ? null : () async {
            if (_formKey.currentState!.validate()) {
              if (_selectedDate == null || _selectedTime == null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("يرجى تحديد موعد الاستلام (اليوم والساعة) 📅", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.orange.shade800,
                ));
                return;
              }

              // 🔥 1. حفظ البيانات محلياً بشكل معزول باسم المستخدم قبل الإرسال
              await _saveCustomerDataLocally();

              // 🚀 2. إرسال الطلبية للسيرفر
              widget.onSubmit(
                _phoneController.text.trim(),
                _wilayaController.text.trim(),
                _addressController.text.trim(),
                _getFormattedDateTime(),
                34.8519, 
                5.7272  
              );
            }
          },
          child: widget.isProcessing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.send_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text("اعتماد وإرسال", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
        ),
      ],
    );
  }
}