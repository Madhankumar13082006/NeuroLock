import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final double radius;

  const BrandLogo({
    super.key,
    this.size = 72,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/images/neurolock_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
