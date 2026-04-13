import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class HitCounter extends StatelessWidget {
  final int count;

  const HitCounter({super.key, this.count = 42069});

  @override
  Widget build(BuildContext context) {
    final formatted = count.toString().padLeft(6, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: RetroColors.neonGreen, width: 2),
        boxShadow: [
          BoxShadow(
            color: RetroColors.neonGreen.withAlpha(76),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text(
        'VISITORS: $formatted',
        style: GoogleFonts.pressStart2p(
          fontSize: 10,
          color: RetroColors.neonGreen,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
