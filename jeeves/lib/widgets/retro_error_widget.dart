import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'retro_button.dart';

class RetroErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const RetroErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ERROR 404',
            style: GoogleFonts.vt323(
              fontSize: 56,
              color: RetroColors.hotPink,
              letterSpacing: 4,
            ),
          ),
          const Text('💀', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.courierPrime(
              fontSize: 13,
              color: RetroColors.white,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            RetroButton(
              label: 'RETRY',
              onPressed: onRetry,
              color: RetroColors.hotPink,
            ),
          ],
        ],
      ),
    );
  }
}
