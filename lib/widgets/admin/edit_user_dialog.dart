import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSuccess;

  const EditUserDialog({super.key, required this.user, required this.onSuccess});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['first_name'] ?? widget.user['username']);
    _phoneController = TextEditingController(text: widget.user['phone'] ?? '');
    _emailController = TextEditingController(text: widget.user['email'] ?? '');
    _passwordController = TextEditingController(); // نتركه فارغاً، نكتب فيه فقط إذا أردنا التغيير
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    Map<String, dynamic> data = {
      "first_name": _nameController.text.trim(),
      "phone": _phoneController.text.trim(),
      "email": _emailController.text.trim(),
    };

    // نرسل الباسورد للسيرفر فقط إذا كتب المدير باسوورد جديد
    if (_passwordController.text.isNotEmpty) {
      data['password'] = _passwordController.text;
    }

    bool success = await ApiService.updateUser(widget.user['id'], data);

    setState(() => _isLoading = false);

    if (success) {
      Navigator.pop(context);
      widget.onSuccess(); // لتحديث القائمة بعد النجاح
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ حدث خطأ أثناء التحديث', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.manage_accounts_rounded, color: Colors.blue.shade800),
          ),
          const SizedBox(width: 10),
          Text("تعديل بيانات الحساب", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(_nameController, "الاسم الكامل", Icons.person),
              const SizedBox(height: 12),
              _buildTextField(_phoneController, "رقم الهاتف", Icons.phone, isNumber: true),
              const SizedBox(height: 12),
              _buildTextField(_emailController, "البريد الإلكتروني", Icons.email),
              const SizedBox(height: 12),
              _buildTextField(_passwordController, "كلمة مرور جديدة (اتركه فارغاً للتخطي)", Icons.lock, isPassword: true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isLoading ? null : _submitUpdate,
          icon: _isLoading 
            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save_rounded, color: Colors.white, size: 18),
          label: Text("حفظ التعديلات", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      obscureText: isPassword,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.blueGrey, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue)),
      ),
    );
  }
}