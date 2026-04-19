import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FleetRadarWidget extends StatelessWidget {
  final List<dynamic> fleetStatus;
  final Function(int driverId, String driverName) onDriverTap;

  const FleetRadarWidget({
    super.key,
    required this.fleetStatus,
    required this.onDriverTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal, 
        padding: const EdgeInsets.symmetric(horizontal: 15), 
        itemCount: fleetStatus.length,
        itemBuilder: (context, index) {
          var driver = fleetStatus[index];
          bool isAvailable = driver['status'] == 'متاح';
          return InkWell(
            onTap: isAvailable ? null : () => onDriverTap(driver['id'], driver['username']),
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 140, margin: const EdgeInsets.symmetric(horizontal: 5), padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(15), 
                border: Border.all(color: isAvailable ? Colors.green.shade200 : Colors.orange.shade400, width: isAvailable ? 1.5 : 2.5)
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: isAvailable ? Colors.green.shade50 : Colors.orange.shade50, 
                    radius: 25, 
                    child: Icon(Icons.local_shipping_rounded, color: isAvailable ? Colors.green : Colors.orange, size: 28)
                  ),
                  const SizedBox(height: 8),
                  Text(
                    driver['username'], 
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14), 
                    maxLines: 1, overflow: TextOverflow.ellipsis
                  ),
                  Text(
                    isAvailable ? "متاح" : "اضغط لرؤية المهام", 
                    style: GoogleFonts.cairo(fontSize: 11, color: isAvailable ? Colors.green : Colors.orange.shade800, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}