import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'marquee_text.dart';

class RetroAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? marqueeText;
  final List<Widget>? actions;

  const RetroAppBar({
    super.key,
    required this.title,
    this.marqueeText,
    this.actions,
  });

  @override
  Size get preferredSize => Size.fromHeight(
      kToolbarHeight + (marqueeText != null ? 24 : 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [RetroColors.darkSurface, RetroColors.darkSurface2],
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.vt323(
              fontSize: 30,
              color: RetroColors.neonGreen,
              letterSpacing: 3,
            ),
          ),
          if (marqueeText != null)
            SizedBox(
              height: 20,
              child: MarqueeText(
                text: marqueeText!,
                style: GoogleFonts.pressStart2p(
                  fontSize: 8,
                  color: RetroColors.electricBlue,
                ),
              ),
            ),
        ],
      ),
      actions: actions,
      backgroundColor: Colors.transparent,
      elevation: 4,
      shadowColor: RetroColors.neonGreen.withAlpha(128),
    );
  }
}
