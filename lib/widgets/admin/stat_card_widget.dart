import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatCardWidget extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isFullWidth;
  final VoidCallback? onTap;

  const StatCardWidget({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.isFullWidth = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.grey.shade200), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
      ), 
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Container(
                  padding: const EdgeInsets.all(8), 
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), 
                  child: Icon(icon, color: iconColor, size: 24)
                ), 
                const SizedBox(height: 12),
                
                // 🔥 حماية الأرقام الطويلة والتنسيق العشري
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value, 
                    style: GoogleFonts.poppins( // استخدام Poppins للأرقام الطويلة
                      fontSize: isFullWidth ? 24 : 18, 
                      fontWeight: FontWeight.bold, 
                      color: const Color(0xFF2C3E50)
                    ),
                    maxLines: 1, // منع النزول لسطر جديد
                  ),
                ), 
                
                // 🔥 حماية العناوين
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    title, 
                    style: GoogleFonts.cairo(
                      fontSize: 13, 
                      color: Colors.grey.shade600, 
                      fontWeight: FontWeight.w600
                    ),
                    maxLines: 1, // منع النزول لسطر جديد
                  ),
                )
              ]
            ),
          ),
        ),
      )
    );
  }
}