import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PixelDivider extends StatelessWidget {
  const PixelDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Text(
            '★',
            style: TextStyle(color: RetroColors.neonGreen, fontSize: 14),
          ),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    RetroColors.neonGreen,
                    RetroColors.electricBlue,
                    RetroColors.neonGreen,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: RetroColors.neonGreen.withAlpha(128),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          const Text(
            '★',
            style: TextStyle(color: RetroColors.neonGreen, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
