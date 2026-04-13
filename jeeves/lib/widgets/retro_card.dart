import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RetroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const RetroCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? RetroColors.darkSurface,
        border: Border.all(color: RetroColors.neonGreen, width: 2),
        boxShadow: [
          BoxShadow(
            color: RetroColors.neonGreen.withAlpha(76),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(3, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
