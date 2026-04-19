import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 استيراد مهم جداً لفحص بيئة الويب
import 'package:google_fonts/google_fonts.dart';
import 'package:nfc_manager/nfc_manager.dart'; 
import '../../services/api_service.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  // 🎨 الألوان المؤسساتية
  final Color primaryRed = const Color(0xFFD32F2F);
  final Color darkBlue = const Color(0xFF1E293B);
  final Color softBg = const Color(0xFFF8FAFC);

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // 📝 متحكمات النصوص (Controllers)
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phone2Ctrl = TextEditingController(); 
  final _phone3Ctrl = TextEditingController(); 
  final _businessNameCtrl = TextEditingController(); 
  final _nfcCtrl = TextEditingController();

  String _selectedRole = 'customer'; // الافتراضي: زبون

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _phone2Ctrl.dispose(); 
    _phone3Ctrl.dispose(); 
    _businessNameCtrl.dispose(); 
    _nfcCtrl.dispose();
    super.dispose();
  }

  // 🚀 دالة الإرسال للسيرفر
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    bool needsNfc = _selectedRole == 'driver' || _selectedRole == 'collector';

    // 🔥 إرسال البيانات للسيرفر بما فيها اسم الشركة
    bool success = await ApiService.registerUser(
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      phone2: _selectedRole == 'customer' ? _phone2Ctrl.text.trim() : null, 
      phone3: _selectedRole == 'customer' ? _phone3Ctrl.text.trim() : null, 
      businessName: _selectedRole == 'customer' ? _businessNameCtrl.text.trim() : null, 
      role: _selectedRole,
      nfcId: needsNfc ? _nfcCtrl.text.trim() : null,
    );

    setState(() => _isLoading = false);

    if (success) {
      String roleName = _selectedRole == 'driver' ? 'السائق' : _selectedRole == 'collector' ? 'المحصل' : 'الزبون';
      _showSnackBar('✅ تم تسجيل $roleName بنجاح!', Colors.green.shade700);
      
      // مسح الحقول بعد النجاح
      _formKey.currentState!.reset();
      _usernameCtrl.clear(); _passwordCtrl.clear(); _firstNameCtrl.clear();
      _lastNameCtrl.clear(); _emailCtrl.clear(); _phoneCtrl.clear();
      _phone2Ctrl.clear(); _phone3Ctrl.clear(); _businessNameCtrl.clear();
      _nfcCtrl.clear();

    } else {
      _showSnackBar('❌ حدث خطأ! قد يكون اسم المستخدم أو البريد مستخدماً مسبقاً.', primaryRed);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ==========================================
  // 📡 دالة قراءة وربط الـ NFC
  // ==========================================
  Future<void> _startNfcScan() async {
    // 🔥 الحماية من الويب (لأن مكتبة NFC ستسبب خطأ في المتصفح)
    if (kIsWeb) {
      _showSnackBar("تقنية الـ NFC لا تعمل في المتصفح. يرجى إدخال الرقم يدوياً عبر قارئ USB.", primaryRed);
      return;
    }

    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        _showSnackBar("حساس الـ NFC غير متوفر أو معطل في هذا الهاتف 🚫", primaryRed);
        return;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: Icon(Icons.contactless_rounded, size: 60, color: darkBlue),
              ),
              const SizedBox(height: 15),
              Text("يرجى تقريب البطاقة من خلف الهاتف للربط...", 
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16), 
                textAlign: TextAlign.center
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(color: primaryRed, backgroundColor: primaryRed.withOpacity(0.1)),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  NfcManager.instance.stopSession();
                  if (Navigator.canPop(dialogCtx)) Navigator.pop(dialogCtx);
                },
                child: Text("إلغاء", style: GoogleFonts.cairo(color: primaryRed, fontWeight: FontWeight.bold)),
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
            // 🔥 الحل السحري لتخطي حماية الدارت في الـ NFC
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
            String nfcId = identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
            
            if (mounted) {
              setState(() {
                _nfcCtrl.text = nfcId;
              });
              _showSnackBar("✅ تم قراءة البطاقة بنجاح", Colors.green.shade700);
            }
          } else {
            _showSnackBar("❌ لم نتمكن من قراءة الشريحة، جرب بطاقة أخرى.", primaryRed);
          }
        }
      );
    } catch (e) {
      _showSnackBar("❌ خطأ غير متوقع في نظام الـ NFC.", primaryRed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb; // 🔥 متغير الويب

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: darkBlue,
        centerTitle: true,
        // 🔥 إخفاء القائمة في الويب لتواجد الـ Sidebar
        leading: isDesktop ? const SizedBox.shrink() : null,
        title: Text("إضافة مستخدم جديد", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryRed))
            : Center(
                // 🔥 تحديد عرض النموذج لكي لا يتمدد بشكل قبيح في شاشات الحاسوب
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("نوع الحساب والصلاحيات"),
                          _buildRoleSelector(),
                          const SizedBox(height: 25),
                          
                          _buildSectionTitle("البيانات الشخصية"),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildTextField(_firstNameCtrl, 'الاسم الأول', Icons.person_outline, isRequired: true)),
                                    const SizedBox(width: 15),
                                    Expanded(child: _buildTextField(_lastNameCtrl, 'اللقب', Icons.group_outlined, isRequired: true)),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                _buildTextField(_phoneCtrl, 'رقم الهاتف الأساسي', Icons.phone_outlined, isPhone: true, isRequired: true),
                                const SizedBox(height: 15),

                                AnimatedSize(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  child: _selectedRole == 'customer' 
                                    ? Column(
                                        children: [
                                          _buildTextField(
                                            _businessNameCtrl, 
                                            'اسم الشركة / النشاط (اختياري)', 
                                            Icons.storefront_rounded,
                                            hint: 'مثال: صيدلية الأمل، مؤسسة البناء...'
                                          ),
                                          const SizedBox(height: 15),
                                          _buildTextField(_phone2Ctrl, 'رقم الهاتف الثاني (اختياري)', Icons.phone_android, isPhone: true),
                                          const SizedBox(height: 15),
                                          _buildTextField(_phone3Ctrl, 'رقم الهاتف الثالث (اختياري)', Icons.phone_android, isPhone: true),
                                          const SizedBox(height: 15),
                                        ],
                                      ) 
                                    : const SizedBox.shrink(),
                                ),

                                _buildTextField(_emailCtrl, 'البريد الإلكتروني', Icons.email_outlined, isEmail: true, isRequired: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 25),

                          _buildSectionTitle("بيانات الدخول للنظام"),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              children: [
                                _buildTextField(_usernameCtrl, 'اسم المستخدم', Icons.alternate_email_rounded, isRequired: true),
                                const SizedBox(height: 15),
                                _buildPasswordField(),
                              ],
                            ),
                          ),

                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: (_selectedRole == 'driver' || _selectedRole == 'collector')
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 25),
                                      _buildSectionTitle("بيانات الربط الميداني (NFC)"),
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.blue.shade200, width: 1.5),
                                        ),
                                        child: _buildNfcField(isDesktop), // 🔥 نمرر متغير الويب هنا
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),

                          const SizedBox(height: 40),

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              onPressed: _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryRed,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.check_circle_outline, size: 24),
                              label: Text('حفظ وتسجيل المستخدم', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 5),
      child: Text(title, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: darkBlue)),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildRoleCard(
                title: 'زبون / متجر',
                icon: Icons.storefront_rounded,
                value: 'customer',
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildRoleCard(
                title: 'سائق توصيل',
                icon: Icons.local_shipping_rounded,
                value: 'driver',
                color: Colors.orange.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildRoleCard(
                title: 'محصل ميداني',
                icon: Icons.account_balance_wallet_rounded,
                value: 'collector',
                color: Colors.teal.shade700,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Container(), 
            ),
          ],
        )
      ],
    );
  }

  Widget _buildRoleCard({required String title, required IconData icon, required String value, required Color color}) {
    bool isSelected = _selectedRole == value;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedRole = value;
        // تصفير الحقول المخصصة عند تغيير الدور
        if (value != 'customer') {
          _phone2Ctrl.clear();
          _phone3Ctrl.clear();
          _businessNameCtrl.clear(); 
        }
        if (value != 'driver' && value != 'collector') {
          _nfcCtrl.clear();
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey.shade500, size: 32),
            const SizedBox(height: 8),
            Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isSelected ? color : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  // 🔥 دالة حقل الـ NFC المحدثة للويب
  Widget _buildNfcField(bool isDesktop) {
    return TextFormField(
      controller: _nfcCtrl,
      readOnly: !isDesktop, // في الويب يمكنه الكتابة، في الجوال للقراءة فقط عبر المسح
      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: darkBlue),
      decoration: InputDecoration(
        labelText: isDesktop ? 'رقم بطاقة NFC (ادخال يدوي أو قارئ USB)' : 'رقم بطاقة NFC (إجباري للميدانيين)',
        labelStyle: GoogleFonts.cairo(color: Colors.grey.shade600, fontSize: 13),
        filled: true,
        fillColor: Colors.blue.shade50,
        prefixIcon: const Icon(Icons.nfc_rounded, color: Colors.blue, size: 20),
        // 🔥 إخفاء زر المسح في الويب
        suffixIcon: isDesktop ? null : Padding(
          padding: const EdgeInsets.all(6.0),
          child: ElevatedButton.icon(
            onPressed: _startNfcScan, 
            style: ElevatedButton.styleFrom(
              backgroundColor: darkBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const Icon(Icons.wifi_tethering, size: 16),
            label: Text("مسح البطاقة", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
        errorStyle: GoogleFonts.cairo(fontSize: 11),
      ),
      validator: (value) {
        if ((_selectedRole == 'driver' || _selectedRole == 'collector') && (value == null || value.trim().isEmpty)) {
          return 'يجب ربط حساب هذا الموظف ببطاقة NFC!';
        }
        return null;
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isRequired = false, bool isEmail = false, bool isPhone = false, String? hint}) {
    return TextFormField(
      controller: controller,
      keyboardType: isEmail ? TextInputType.emailAddress : (isPhone ? TextInputType.phone : TextInputType.text),
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.cairo(color: Colors.grey.shade600, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
        filled: true,
        fillColor: softBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: darkBlue, width: 1.5)),
        errorStyle: GoogleFonts.cairo(fontSize: 11),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) return 'هذا الحقل مطلوب';
        if (isEmail && value != null && value.isNotEmpty && !value.contains('@')) return 'بريد إلكتروني غير صالح';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordCtrl,
      obscureText: !_isPasswordVisible,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: 'كلمة المرور',
        labelStyle: GoogleFonts.cairo(color: Colors.grey.shade600, fontSize: 13),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.grey.shade500, size: 20),
        suffixIcon: IconButton(
          icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade500, size: 20),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
        filled: true,
        fillColor: softBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: darkBlue, width: 1.5)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'كلمة المرور مطلوبة';
        if (value.length < 3) return 'كلمة المرور قصيرة جداً';
        return null;
      },
    );
  }
}