import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserListCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Function(int userId, String userName) onDelete;

  const UserListCard({
    super.key,
    required this.user,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDriver = user['role'] == 'driver';
    final bool isAdmin = user['role'] == 'admin';

    // 🎨 تحديد الألوان والأيقونات بناءً على الرتبة باحترافية
    Color avatarBg = isAdmin ? Colors.red.shade50 : (isDriver ? Colors.blue.shade50 : Colors.orange.shade50);
    Color iconColor = isAdmin ? Colors.red.shade700 : (isDriver ? Colors.blue.shade700 : Colors.orange.shade800);
    IconData roleIcon = isAdmin ? Icons.shield_rounded : (isDriver ? Icons.local_shipping_rounded : Icons.storefront_rounded);
    String roleName = isAdmin ? 'مدير نظام' : (isDriver ? 'سائق توصيل' : 'زبون / متجر');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 🎭 الأيقونة الدائرية
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: avatarBg, shape: BoxShape.circle),
            child: Icon(roleIcon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 15),

          // 🔥 الحماية المنيعة 1: Expanded لمنع انضغاط الاسم
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['username'] ?? 'بدون اسم',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // 🏷️ شارة الدور (Badge)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(roleName, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: iconColor)),
                    ),
                    const SizedBox(width: 8),
                    // 🔥 الحماية المنيعة 2: Expanded للإيميل لكي لا يدفع الشارة
                    Expanded(
                      child: Text(
                        user['email'] ?? 'لا يوجد بريد',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),

          const SizedBox(width: 10),

          // 🛡️ زر الحذف أو شارة الحماية
          isAdmin 
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.gpp_good_rounded, color: Colors.red.shade700, size: 14),
                    const SizedBox(width: 4),
                    Text("محمي", style: GoogleFonts.cairo(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            : IconButton(
                onPressed: () => onDelete(user['id'], user['username']),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                tooltip: 'حذف المستخدم',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
              ),
        ],
      ),
    );
  }
}