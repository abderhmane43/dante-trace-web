import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget desktopBody;

  const ResponsiveLayout({
    super.key,
    required this.mobileBody,
    required this.desktopBody,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // إذا كان عرض الشاشة أقل من 800 بكسل (هاتف أو تابلت صغير)
        if (constraints.maxWidth < 800) {
          return mobileBody;
        } 
        // إذا كان العرض أكبر من 800 بكسل (شاشة حاسوب)
        else {
          return desktopBody;
        }
      },
    );
  }
}