import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderTimelineWidget extends StatelessWidget {
  final String currentStatus;
  final String approvalStatus;

  const OrderTimelineWidget({
    super.key,
    required this.currentStatus,
    required this.approvalStatus,
  });

  // 🔥 تحديد الخطوة الحالية بناءً على حالة الطرد الصارمة في السيرفر الجديد
  int _getCurrentStep() {
    if (currentStatus == 'pending_approval' && approvalStatus == 'pending') return 1;
    
    switch (currentStatus.toLowerCase()) {
      case 'pending': return 0;
      case 'pending_approval': return 1;
      case 'approved': return 2;
      case 'assigned': return 3;
      case 'picked_up': 
      case 'in_transit': return 4;
      case 'delivered': return 5;
      case 'delivered_unpaid': return 5; // تم التوصيل ولكن بالآجل
      case 'assigned_to_collector': return 5; // المحصل في طريقه
      case 'settled_with_collector': 
      case 'settled': return 6;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int currentStep = _getCurrentStep();
    final bool isUnpaidDebt = currentStatus == 'delivered_unpaid' || currentStatus == 'assigned_to_collector';
    
    // قائمة المراحل السبع الصارمة المحدثة
    final List<Map<String, dynamic>> steps = [
      {"title": "معالجة", "icon": Icons.inventory_2_outlined},
      {"title": "بانتظار الموافقة", "icon": Icons.rule_rounded},
      {"title": "معتمد", "icon": Icons.thumb_up_alt_outlined},
      {"title": "مُسند لسائق", "icon": Icons.assignment_ind_outlined},
      {"title": "في الطريق", "icon": Icons.local_shipping_outlined},
      {"title": isUnpaidDebt ? "مستلم (دَين)" : "تم التسليم", "icon": isUnpaidDebt ? Icons.money_off_rounded : Icons.check_circle_outline},
      {"title": "مغلقة", "icon": Icons.lock_outline},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              "مسار الطرد المباشر 📍",
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey.shade800),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: List.generate(steps.length, (index) {
              bool isCompleted = index < currentStep;
              bool isActive = index == currentStep;
              
              // 🔥 تغيير اللون إلى برتقالي تحذيري إذا كانت الطلبية مستلمة ديناً (unpaid)
              Color stepColor;
              if (isCompleted || isActive) {
                if (index == 5 && isUnpaidDebt) {
                  stepColor = Colors.orange.shade700;
                } else if (index == 6 && isUnpaidDebt && !isCompleted && !isActive) {
                  stepColor = Colors.grey.shade300;
                } else {
                  stepColor = Colors.green.shade600;
                }
              } else {
                stepColor = Colors.grey.shade300;
              }

              // إذا كانت المرحلة نشطة (Active)، نجعلها زرقاء (إلا إذا كانت ديناً)
              if (isActive && !(index == 5 && isUnpaidDebt)) {
                stepColor = Colors.blue.shade700;
              }
              
              return Expanded(
                child: Column(
                  children: [
                    // الدائرة والخط الواصل
                    Row(
                      children: [
                        // الخط الأيمن (يختفي في العنصر الأول)
                        Expanded(
                          child: Container(
                            height: 3,
                            color: index == 0 ? Colors.transparent : (isCompleted || isActive ? Colors.green.shade600 : Colors.grey.shade200),
                          ),
                        ),
                        // الدائرة التي تحتوي على الأيقونة
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isActive ? stepColor.withOpacity(0.1) : (isCompleted ? stepColor : Colors.white),
                            shape: BoxShape.circle,
                            border: Border.all(color: stepColor, width: isActive ? 2 : 1),
                            boxShadow: isActive ? [BoxShadow(color: stepColor.withOpacity(0.3), blurRadius: 6)] : [],
                          ),
                          child: Icon(
                            steps[index]['icon'],
                            size: 12,
                            color: isCompleted ? Colors.white : stepColor,
                          ),
                        ),
                        // الخط الأيسر (يختفي في العنصر الأخير)
                        Expanded(
                          child: Container(
                            height: 3,
                            color: index == steps.length - 1 ? Colors.transparent : (isCompleted ? Colors.green.shade600 : Colors.grey.shade200),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // اسم المرحلة
                    Text(
                      steps[index]['title'],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      style: GoogleFonts.cairo(
                        fontSize: 8,
                        fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
                        color: isActive || isCompleted ? Colors.blueGrey.shade900 : Colors.grey.shade500,
                        height: 1.2
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}